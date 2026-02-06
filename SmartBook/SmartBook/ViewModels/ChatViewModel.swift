// ChatViewModel.swift - 聊天视图模型

import Combine
import Foundation
import SwiftUI

/// 聊天视图模型
class ChatViewModel: ObservableObject {
    @Published var currentMessageId: UUID?
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var showScrollToBottom = false
    @Published var mediaItems: [MediaItem] = []
    @Published var scrollBottom = 0.0
    var scrollProxy: ScrollViewProxy?
    var answerMessageId = UUID()
    var reducedScrollBottom = false
    var keyboardChanging = false
    var safeAreaBottom = 0.0
    
    // MARK: - 摘要配置
    
    /// 摘要触发阈值（同时也是保留的历史消息数量）
    let summarizationThreshold = 3

    var bookState: BookState?
    var historyService: ChatHistoryService?
    var summarizationService: SummarizationService?
    var selectedAssistant: Assistant?
    var selectedModel: String = "gemini-2.0-flash"
    private let streamingService: StreamingChatService
    private var streamingContent = ""
    private var answerContents = [String]()
    private var contentIndex = 0
    private var wordIndex = 0
    private var currentMessageIndex = 0
    private var wordTimer: Timer?

    // 流式 TTS 服务（Google TTS）
    @Published var ttsStreamService = TTSStreamService()

    // 原生 TTS 服务（iOS 系统语音）
    private let ttsService = TTSService()

    // TTS 提供商配置
    @AppStorage(AppConfig.Keys.ttsProvider) private var ttsProvider = AppConfig.DefaultValues.ttsProvider

    // 依赖注入，方便测试和管理
    init(streamingService: StreamingChatService = StreamingChatService()) {
        self.streamingService = streamingService

        // 设置 TTS 播放完成回调（合并所有必要逻辑）
        Logger.info("🔧 ChatViewModel.init: 正在设置播放完成回调")
        ttsStreamService.setOnPlaybackComplete { [weak self] in
            Logger.info("🔔 播放完成回调被触发！")

            guard let self = self else { return }

            Task { @MainActor in
                Logger.info("🔧 播放前状态: isLoading=\(self.isLoading), isPlaying=\(self.ttsStreamService.isPlaying)")

                // 设置播放状态为 false
                self.ttsStreamService.isPlaying = false

                Logger.info("✅ TTS 播放完成: isLoading=\(self.isLoading), isPlaying=\(self.ttsStreamService.isPlaying)")
            }
        }
    }

    // MARK: - 历史记录管理

    /// 加载当前对话的历史消息
    func loadCurrentConversation() {
        guard let historyService = historyService else { return }
        messages = historyService.loadMessages()
        Logger.info("📖 加载了 \(messages.count) 条历史消息")
    }

    /// 创建新对话（不立即保存到数据库，等待第一条消息）
    func startNewConversation() {
        // 清空当前对话引用，但不创建数据库记录
        historyService?.currentConversation = nil

        messages.removeAll()
        streamingContent = ""
        Logger.info("✨ 准备开始新对话（等待第一条消息）")
    }

    /// 切换到指定对话
    func switchToConversation(_ conversation: Conversation) {
        historyService?.switchToConversation(conversation)
        loadCurrentConversation()
    }

    func scrollToBottom(animate: Bool = true) {
        if animate {
            withAnimation {
                scrollProxy?.scrollTo("bottomAnchor", anchor: .bottom)
            }
        } else {
            scrollProxy?.scrollTo("bottomAnchor", anchor: .bottom)
        }
    }

    /// 停止AI响应和TTS播放
    func stopAnswer() {
        // 停止 AI 文本生成
        streamingService.stopStreaming()
        isLoading = false

        // 停止所有 TTS 播放
        Task { @MainActor in
            // 停止 Google TTS
            await ttsStreamService.stopTTS()

            // 停止原生 TTS
            ttsService.stop()

            Logger.info("⏹️ 已停止 AI 生成和所有 TTS 播放")
        }
    }

    @MainActor
    func sendMessage(_ text: String, mediaItems: [MediaItem] = [], enableTTS: Bool = false) async {
        guard let bookState = bookState else { return }

        // 处理媒体数据
        var mediaDescription = ""
        if !mediaItems.isEmpty {
            Logger.info("📎 处理 \(mediaItems.count) 个媒体项")

            for (index, item) in mediaItems.enumerated() {
                switch item.type {
                case .image(let image):
                    // 图片转base64（供日志使用）
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        let sizeKB = Double(imageData.count) / 1024.0
                        mediaDescription +=
                            "\n[图片 \(index + 1): \(Int(image.size.width))x\(Int(image.size.height)), \(String(format: "%.1f", sizeKB))KB]"
                        Logger.info(
                            "📸 图片 \(index + 1): \(Int(image.size.width))x\(Int(image.size.height)), \(String(format: "%.1f", sizeKB))KB"
                        )
                    }

                case .document(let url):
                    // 读取文档内容
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        let preview = String(content.prefix(100))
                        mediaDescription +=
                            "\n[文档 \(index + 1): \(url.lastPathComponent), \(content.count) 字符]\n预览: \(preview)..."
                        Logger.info("📄 文档 \(index + 1): \(url.lastPathComponent), \(content.count) 字符")
                    }
                }
            }
        }

        // 过滤空字符串（如果有媒体，文本可以为空）
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.count == 0 && mediaItems.isEmpty {
            Logger.warning("⚠️ 消息太短且无媒体，拒绝发送")
            return
        }

        // 组合消息内容
        let finalContent = trimmedText + mediaDescription
        Logger.info(
            "📤 发送消息: \(trimmedText.isEmpty ? "[仅媒体]" : trimmedText), 媒体: \(mediaItems.count), TTS: \(enableTTS)"
        )

        // 先获取上下文（在添加新消息之前）
        let (summary, recentMessages) = summarizationService?.getContext(
            messages: messages,
            conversation: historyService?.currentConversation
        ) ?? (nil, Array(messages.suffix(3)))

        // 再添加用户消息
        let userMessage = ChatMessage(role: .user, content: finalContent)
        messages.append(userMessage)
        currentMessageId = userMessage.id

        // 保存用户消息
        historyService?.saveMessage(userMessage)

        isLoading = true
        streamingContent = ""
        answerContents.removeAll()
        contentIndex = 0
        cancelDisplay()

        // 创建一个临时的助手消息用于流式更新
        let streamingMessage = ChatMessage(role: .assistant, content: "",isStreaming: true)
        messages.append(streamingMessage)
        answerMessageId = streamingMessage.id
        let messageIndex = messages.count - 1
        currentMessageIndex = messageIndex

        // 如果启用 TTS 且使用 Google，启动流式 TTS
        if enableTTS && ttsProvider == "google" {
            Task {
                if !ttsStreamService.isConnected {
                    await ttsStreamService.connect()
                }
                await ttsStreamService.startTTS()

                // 等待一点时间确保 Deepgram 握手成功
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5秒

                Logger.info("🔊 Google TTS 已就绪")
            }
        }

        // 处理图片数据（转base64）
        var imagesData: [[String: Any]]? = nil
        if !mediaItems.isEmpty {
            var images: [[String: Any]] = []
            for item in mediaItems {
                switch item.type {
                case .image(let image):
                    // 转JPEG并编码为base64
                    if let jpegData = image.jpegData(compressionQuality: 0.8) {
                        let base64String = jpegData.base64EncodedString()
                        images.append([
                            "data": base64String,
                            "mime_type": "image/jpeg",
                        ])
                    }
                case .document:
                    // 文档暂不支持Vision，跳过
                    break
                }
            }

            if !images.isEmpty {
                imagesData = images
                Logger.info("📸 准备发送 \(images.count) 张图片到服务器")
            }
        }

        // 使用流式API
        let assistant = selectedAssistant ?? Assistant.defaultAssistants.first!
        streamingService.sendMessageStream(
            message: trimmedText,
            assistant: assistant,
            bookId: bookState.selectedBook?.id,
            model: selectedModel,
            ragEnabled: false,
            summary: summary,
            history: recentMessages,
            images: imagesData
        ) { [weak self] event in
            guard let self = self else { return }

            // 修复：在 Task 内部也使用 weak self 避免循环引用
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch event {
                case .content(let content):
                    Logger.info("💬 收到内容: \(content)")
                    // 逐步更新内容
                    self.answerContents.append(content)
                    self.wordByWordDisplay()

                    // 只在使用 Google TTS 时发送流式文本
                    if enableTTS && self.ttsProvider == "google" {
                        Task {
                            await self.ttsStreamService.sendText(content)
                        }
                    }

                case .error(let error):
                    if messageIndex < self.messages.count {
                        self.cancelDisplay()
                        self.messages[messageIndex] = ChatMessage(
                            id: self.messages[messageIndex].id,
                            role: .assistant,
                            content: "❌ 错误: \(error)",
                            isStreaming: false
                        )
                    }

                default:
                    break
                }
            }
        } onComplete: { [weak self] result in
            guard let self = self else { return }
            // 修复：在 Task 内部也使用 weak self 避免循环引用
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch result {
                case .failure(let error):
                    self.isLoading = false
                    self.cancelDisplay()

                    // 停止 TTS（用户取消时）
                    Task {
                        await self.ttsStreamService.stopTTS()
                        self.ttsService.stop()
                    }

                    // 检查是否是用户主动取消
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        // 用户主动取消，标记消息但不保存到数据库
                        if messageIndex < self.messages.count {
                            let currentMessage = self.messages[messageIndex]
                            let currentContent = self.answerContents.joined()

                            self.messages[messageIndex] = ChatMessage(
                                id: currentMessage.id,
                                role: currentMessage.role,
                                content: currentContent.isEmpty ? "⏹️ 用户已停止" : currentContent,
                                timestamp: currentMessage.timestamp,
                                thinking: currentMessage.thinking,
                                sources: currentMessage.sources,
                                usage: currentMessage.usage,
                                systemPrompt: currentMessage.systemPrompt,
                                stoppedByUser: true,
                                isStreaming: false,
                            )
                        }
                        Logger.info("⏹️ 用户取消了请求，不保存到数据库")
                        // 注意：这里不调用 saveMessage()，不保存到数据库
                    } else {
                        // 真正的错误
                        if messageIndex < self.messages.count {
                            self.messages[messageIndex] = ChatMessage(
                                id: self.messages[messageIndex].id,
                                role: .assistant,
                                content: "❌ 请求失败: \(error.localizedDescription)",
                                isStreaming: false
                            )
                        }
                    }
                case .success:
                    // 流式完成，内容已经在事件中更新

                    // 保存助手消息到数据库
                    if messageIndex < self.messages.count {
                        let messageContent = self.answerContents.joined()
                        let finalMessage = ChatMessage(
                            id: self.messages[messageIndex].id,
                            role: .assistant,
                            content: messageContent
                        )
                        self.historyService?.saveMessage(finalMessage)
                        Logger.info("💾 保存助手回复到数据库")

                        // 根据 TTS provider 选择播放方式
                        if enableTTS {
                            Logger.info("🔊 TTS Provider: \(self.ttsProvider)")

                            if self.ttsProvider == "native" {
                                // 使用 iOS 原生语音
                                Task {
                                    await self.ttsService.speak(messageContent)
                                    Logger.info("🔊 使用 iOS 原生语音朗读")
                                }
                            } else if self.ttsProvider == "google" {
                                // Google TTS 已通过 WebSocket 接收音频
                                // 发送 flush 触发播放
                                Task {
                                    await self.ttsStreamService.flush()
                                    Logger.info("🔊 Google TTS flush 已发送，等待播放")
                                }
                            } else {
                                Logger.warning("⚠️ 未知的 TTS provider: \(self.ttsProvider)")
                            }
                        }

                        // 检查是否需要生成摘要
                        self.summarizationService?.checkAndTriggerSummarization(
                            messages: self.messages,
                            conversation: self.historyService?.currentConversation,
                            historyService: self.historyService
                        )
                    }
                    break
                }
            }
        }
    }

    func clearMessages() {
        historyService?.clearCurrentConversationMessages()
        messages.removeAll()
        streamingContent = ""
    }

    func wordByWordDisplay() {
        if wordTimer == nil {
            wordTimer = Timer.scheduledTimer(
                withTimeInterval: 0.12,
                repeats: true,
                block: { _ in
                    if self.contentIndex < self.answerContents.count {
                        let content = self.answerContents[self.contentIndex]
                        let words = content.map { String($0) }
                        if self.wordIndex < words.count {
                            let remainingCount = words.count - self.wordIndex
                            let takeCount = min(3, remainingCount)
                            let wordChars = words[self.wordIndex..<(self.wordIndex + takeCount)]
                            let word = wordChars.joined()
                            if self.currentMessageIndex < self.messages.count {
                                self.streamingContent += word
                                self.messages[self.currentMessageIndex] = ChatMessage(
                                    id: self.messages[self.currentMessageIndex].id,
                                    role: .assistant,
                                    content: self.streamingContent,
                                    isStreaming: true
                                )
                                self.wordIndex += takeCount
                            }
                        } else {
                            self.wordIndex = 0
                            self.contentIndex += 1
                        }
                    } else {
                        self.messages[self.currentMessageIndex] = ChatMessage(
                            id: self.messages[self.currentMessageIndex].id,
                            role: .assistant,
                            content: self.streamingContent,
                            isStreaming: false
                        )
                        self.isLoading = false
                        self.cancelDisplay()
                    }
                }
            )
        }
    }

    func cancelDisplay() {
        wordTimer?.invalidate()
        wordTimer = nil
    }
}
