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


    var bookState: BookState?
    var historyService: ChatHistoryService?
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

        // 获取上下文（摘要 + 最近消息）
        let (summary, recentMessages) = getContext()

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
            ragEnabled: true,
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
                        self.checkAndTriggerSummarization()
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

    // MARK: - 上下文管理

    /// 获取对话上下文（摘要 + 最近消息）
    /// 返回：(摘要文本, 最近消息数组)
    private func getContext() -> (String?, [ChatMessage]) {
        guard let conversation = historyService?.currentConversation else {
            return (nil, Array(messages.suffix(10)))
        }

        let summarizedCount = conversation.summarizedMessageCount

        // 如果有摘要，返回摘要 + 未摘要的消息
        if let summary = conversation.summary, summarizedCount > 0 {
            let unsummarizedMessages = Array(messages.dropFirst(summarizedCount))
            let recentMessages = Array(unsummarizedMessages.suffix(10))
            Logger.info("📝 使用摘要 (\(summarizedCount)条) + 最近\(recentMessages.count)条消息")
            return (summary, recentMessages)
        }

        // 没有摘要，返回最近10条
        let recentMessages = Array(messages.suffix(10))
        return (nil, recentMessages)
    }

    /// 检查是否需要生成摘要
    /// 当消息数量超过20条且没有摘要时触发
    private func checkAndTriggerSummarization() {
        guard let conversation = historyService?.currentConversation else { return }

        let totalMessages = messages.count
        let summarizedCount = conversation.summarizedMessageCount
        let unsummarizedCount = totalMessages - summarizedCount

        // 超过20条未摘要的消息时触发
        if unsummarizedCount >= 20 {
            Task {
                await generateSummary()
            }
        }
    }

    /// 生成对话摘要
    @MainActor
    private func generateSummary() async {
        guard let conversation = historyService?.currentConversation else { return }

        let summarizedCount = conversation.summarizedMessageCount
        let messagesToSummarize = Array(messages.dropFirst(summarizedCount).prefix(10))

        if messagesToSummarize.isEmpty {
            return
        }

        Logger.info("🤖 开始生成摘要，处理 \(messagesToSummarize.count) 条消息...")

        // 构建摘要请求
        var conversationText = ""
        if let existingSummary = conversation.summary {
            conversationText += "【之前的摘要】\n\(existingSummary)\n\n【新对话】\n"
        }

        for msg in messagesToSummarize {
            let role = msg.role == .user ? "用户" : "AI"
            conversationText += "\(role): \(msg.content)\n\n"
        }

        let summarizePrompt = """
            请将以上对话总结成一个简洁的摘要，保留关键信息和上下文。
            摘要应该：
            1. 概括主要讨论的话题
            2. 记录重要的结论或决定
            3. 保持简洁，不超过200字
            """

        // 调用 AI 生成摘要（使用流式 API）
        var generatedSummary = ""

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // 使用通用聊天助手生成摘要
            let chatAssistant = Assistant(
                id: "summarize",
                name: "摘要助手",
                avatar: "📝",
                color: "#9c27b0",
                description: "对话摘要助手",
                systemPrompt: "你是一个专业的对话摘要助手。",
                action: .chat,
                useRAG: false
            )

            streamingService.sendMessageStream(
                message: conversationText + "\n\n" + summarizePrompt,
                assistant: chatAssistant,
                bookId: nil,
                model: "gemini-2.0-flash",  // 使用快速模型生成摘要
                ragEnabled: false,
                summary: nil,
                history: []  // 摘要请求不需要历史
            ) { event in
                // 收集摘要内容
                if case .content(let content) = event {
                    generatedSummary += content
                }
            } onComplete: { result in
                // 摘要生成完成
                continuation.resume()
            }
        }

        // 保存生成的摘要
        if !generatedSummary.isEmpty {
            conversation.summary = generatedSummary
            conversation.summarizedMessageCount = summarizedCount + messagesToSummarize.count

            historyService?.saveSummary(summary: generatedSummary, messageCount: conversation.summarizedMessageCount)
            Logger.info("✅ AI 摘要已保存，已摘要消息数: \(conversation.summarizedMessageCount)")
            Logger.info("📝 摘要内容: \(generatedSummary.prefix(100))...")
        } else {
            Logger.error("❌ 摘要生成失败，内容为空")
        }
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
