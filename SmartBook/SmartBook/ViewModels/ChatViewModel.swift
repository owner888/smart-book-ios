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
    @Published var inputText = ""
    var scrollProxy: ScrollViewProxy?
    var answerMessageId: UUID?
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
    var selectedModel: String = AppConfig.DefaultValues.defaultModel
    private let streamingService: StreamingChatService
    private var streamingContent = ""
    private var streamingThinking = ""  // 思考过程
    private var streamingSources: [RAGSource]?  // 检索来源
    private var streamingTools: [ToolInfo]?  // 工具调用
    private var answerContents = [String]()
    private var contentIndex = 0
    private var wordIndex = 0
    private var currentMessageIndex = 0
    private var wordTimer: Timer?

    // TTS 协调服务（统一管理多个 TTS 提供商）
    private let ttsCoordinator: TTSCoordinatorService

    // 流式 TTS 服务（Google TTS）- 保留用于直接访问
    @Published var ttsStreamService: TTSStreamService

    // 媒体处理服务
    private let mediaService: MediaProcessingService

    // TTS 提供商配置
    @AppStorage(AppConfig.Keys.ttsProvider) private var ttsProvider = AppConfig.DefaultValues.ttsProvider {
        didSet {
            // 提供商变化时更新协调服务
            ttsCoordinator.updateProvider(ttsProvider)
        }
    }

    deinit {
        cancelDisplay()
        Logger.info("♻️ ChatViewModel 已释放")
    }

    // 依赖注入，方便测试和管理
    init(
        streamingService: StreamingChatService = StreamingChatService(),
        ttsCoordinator: TTSCoordinatorService? = nil,
        ttsStreamService: TTSStreamService? = nil,
        mediaService: MediaProcessingService? = nil
    ) {
        let resolvedTTSStream = ttsStreamService ?? TTSStreamService()
        self.streamingService = streamingService
        self.ttsStreamService = resolvedTTSStream
        self.ttsCoordinator =
            ttsCoordinator
            ?? TTSCoordinatorService(
                nativeTTS: DIContainer.shared.ttsService,
                streamTTS: resolvedTTSStream,
                provider: AppConfig.DefaultValues.ttsProvider
            )
        self.mediaService = mediaService ?? MediaProcessingService()

        // 确保 ViewModel 释放时清理 Timer
        Logger.info("🏗️ ChatViewModel 已创建")

        // 设置 TTS 播放完成回调（合并所有必要逻辑）
        Logger.info("🔧 ChatViewModel.init: 正在设置播放完成回调")
        self.ttsStreamService.setOnPlaybackComplete { [weak self] in
            Logger.info("🔔 播放完成回调被触发！")

            guard let self = self else { return }

            Task { @MainActor in
                Logger.info("🔧 播放前状态: isLoading=\(self.isLoading), isPlaying=\(self.ttsStreamService.isPlaying)")

                // 设置播放状态为 false
                self.ttsStreamService.isPlaying = false

                Logger.info("TTS 播放完成: isLoading=\(self.isLoading), isPlaying=\(self.ttsStreamService.isPlaying)")
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

        // 使用协调服务停止所有 TTS
        Task { @MainActor in
            await ttsCoordinator.stopAll()
        }
    }

    @MainActor
    func sendMessage(_ text: String, mediaItems: [MediaItem] = [], enableTTS: Bool = false) async {
        guard let bookState = bookState else { return }

        // 使用媒体处理服务
        let processedMedia = mediaService.processMediaItems(mediaItems)

        // 过滤空字符串（如果有媒体，文本可以为空）
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty && processedMedia.images == nil {
            Logger.warning("⚠️ 消息太短且无媒体，拒绝发送")
            return
        }

        answerMessageId = nil

        // 用户消息内容（不包含媒体描述，像 Grok 一样）
        let finalContent = trimmedText
        Logger.info(
            "📤 发送消息: \(trimmedText.isEmpty ? "[仅媒体]" : trimmedText), 媒体: \(mediaItems.count), TTS: \(enableTTS)"
        )

        // 先获取上下文（在添加新消息之前）
        let (summary, recentMessages) =
            summarizationService?.getContext(
                messages: messages,
                conversation: historyService?.currentConversation
            ) ?? (nil, Array(messages.suffix(summarizationThreshold)))

        // 再添加用户消息（包含媒体项）
        let userMessage = ChatMessage(
            role: .user,
            content: finalContent,
            mediaItems: mediaItems.isEmpty ? nil : mediaItems
        )
        messages.append(userMessage)
        currentMessageId = userMessage.id

        // 保存用户消息
        historyService?.saveMessage(userMessage)

        isLoading = true
        streamingContent = ""
        streamingThinking = ""  // 重置思考内容
        streamingSources = nil  // 重置检索来源
        streamingTools = nil  // 重置工具调用
        answerContents.removeAll()
        contentIndex = 0
        cancelDisplay()

        // 创建一个临时的助手消息用于流式更新
        let streamingMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(streamingMessage)
        answerMessageId = streamingMessage.id
        let messageIndex = messages.count - 1
        currentMessageIndex = messageIndex

        // 如果启用 TTS，准备流式 TTS（仅 Google）
        if enableTTS {
            Task {
                await ttsCoordinator.prepareStreaming()
            }
        }

        // 使用流式API
        let assistant = selectedAssistant ?? Assistant.defaultAssistants.first!
        streamingService.sendMessageStream(
            message: trimmedText,
            assistant: assistant,
            bookId: bookState.selectedBook?.id,
            model: selectedModel,
            enableRag: false,
            summary: summary,
            history: recentMessages,
            images: processedMedia.images  // 直接使用处理后的图片数据
        ) { [weak self] event in
            guard let self = self else { return }

            // 修复：在 Task 内部也使用 weak self 避免循环引用
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch event {
                case .sources(let sources):
                    Logger.info("📚 收到检索来源: \(sources.count) 个")
                    // 保存检索来源
                    self.streamingSources = sources

                    // 更新消息显示来源
                    if messageIndex < self.messages.count {
                        self.messages[messageIndex] = ChatMessage(
                            id: self.messages[messageIndex].id,
                            role: .assistant,
                            content: self.streamingContent,
                            thinking: self.streamingThinking,
                            sources: sources,  // 添加检索来源
                            tools: self.streamingTools,  // 保留工具
                            isStreaming: true
                        )
                    }

                case .tools(let tools):
                    Logger.info("🔧 收到工具调用事件！")
                    Logger.info("🔧 工具数量: \(tools.count)")
                    Logger.info("🔧 工具详情: \(tools.map { "\($0.name)(\($0.success ? "成功" : "失败"))" })")

                    // 保存工具调用
                    self.streamingTools = tools

                    // 更新消息显示工具
                    if messageIndex < self.messages.count {
                        Logger.info("🔧 更新消息显示工具")
                        self.messages[messageIndex] = ChatMessage(
                            id: self.messages[messageIndex].id,
                            role: .assistant,
                            content: self.streamingContent,
                            thinking: self.streamingThinking,
                            sources: self.streamingSources,  // 保留来源
                            tools: tools,  // 添加工具调用
                            isStreaming: true
                        )
                    } else {
                        Logger.error("❌ messageIndex 越界: \(messageIndex) >= \(self.messages.count)")
                    }

                case .thinking(let thinkingText):
                    Logger.info("🧠 收到思考: \(thinkingText.prefix(50))...")
                    // 累积思考内容
                    self.streamingThinking += thinkingText

                    // 更新消息显示思考过程
                    if messageIndex < self.messages.count {
                        self.messages[messageIndex] = ChatMessage(
                            id: self.messages[messageIndex].id,
                            role: .assistant,
                            content: self.streamingContent,
                            thinking: self.streamingThinking,  // 添加思考内容
                            sources: self.streamingSources,  // 保留来源
                            isStreaming: true
                        )
                    }

                case .content(let content):
                    Logger.info("💬 收到内容: \(content)")
                    // 逐步更新内容
                    self.answerContents.append(content)
                    self.wordByWordDisplay()

                    // 使用协调服务发送流式文本
                    if enableTTS {
                        Task {
                            await self.ttsCoordinator.sendStreamingText(content)
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

                    // 使用协调服务停止 TTS
                    Task {
                        await self.ttsCoordinator.stopAll()
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

                    // 保存助手消息到数据库（包含 thinking 和 sources）
                    if messageIndex < self.messages.count {
                        let messageContent = self.answerContents.joined()
                        let finalMessage = ChatMessage(
                            id: self.messages[messageIndex].id,
                            role: .assistant,
                            content: messageContent,
                            thinking: self.streamingThinking.isEmpty ? nil : self.streamingThinking,  // 保存思考内容
                            sources: self.streamingSources  // 保存检索来源
                        )
                        self.historyService?.saveMessage(finalMessage)
                        Logger.info(
                            "💾 保存助手回复到数据库（thinking: \(self.streamingThinking.isEmpty ? "无" : "有"), sources: \(self.streamingSources?.count ?? 0)）"
                        )

                        // 使用协调服务播放 TTS
                        if enableTTS {
                            Task {
                                await self.ttsCoordinator.speak(messageContent)
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
                block: { [weak self] _ in
                    guard let self = self else { return }
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
                                    thinking: self.streamingThinking.isEmpty ? nil : self.streamingThinking,  // 保留思考内容
                                    sources: self.streamingSources,  // 保留检索来源
                                    tools: self.streamingTools,  // 保留工具调用
                                    isStreaming: true
                                )
                                self.wordIndex += takeCount
                            }
                        } else {
                            self.wordIndex = 0
                            self.contentIndex += 1
                        }
                    } else {
                        if self.currentMessageIndex < self.messages.count {
                            self.messages[self.currentMessageIndex] = ChatMessage(
                                id: self.messages[self.currentMessageIndex].id,
                                role: .assistant,
                                content: self.streamingContent,
                                thinking: self.streamingThinking.isEmpty ? nil : self.streamingThinking,  // 保留思考内容
                                sources: self.streamingSources,  // 保留检索来源
                                tools: self.streamingTools,  // 保留工具调用
                                isStreaming: false
                            )
                        }
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
