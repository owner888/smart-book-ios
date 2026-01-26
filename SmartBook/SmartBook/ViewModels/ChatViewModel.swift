// ChatViewModel.swift - 聊天视图模型

import Foundation
import SwiftUI
import Combine

/// 聊天视图模型
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var showScrollToBottom = false
    @Published var questionMessageId: UUID?
    var scrollProxy: ScrollViewProxy?

    var bookState: BookState?
    var historyService: ChatHistoryService?
    private let streamingService: StreamingChatService
    private var streamingContent = ""
    
    // 依赖注入，方便测试和管理
    init(streamingService: StreamingChatService = StreamingChatService()) {
        self.streamingService = streamingService
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

    
    func scrollToBottom() {
        withAnimation {
            scrollProxy?.scrollTo("bottomAnchor", anchor: .bottom)
        }
    }
    
    /// 停止AI响应
    func stopAnswer() {
        streamingService.stopStreaming()
        isLoading = false
    }

    @MainActor
    func sendMessage(_ text: String) async {
        guard let bookState = bookState else { return }

        Logger.info("📤 发送消息: \(text)")
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        questionMessageId = userMessage.id
        
        // 保存用户消息
        historyService?.saveMessage(userMessage)

        isLoading = true
        streamingContent = ""

        // 创建一个临时的助手消息用于流式更新
        let streamingMessage = ChatMessage(role: .assistant, content: "")
        messages.append(streamingMessage)
        let messageIndex = messages.count - 1

        // 获取上下文（摘要 + 最近消息）
        let (summary, recentMessages) = getContext()
        
        // 使用流式API
        streamingService.sendMessageStream(
            message: text,
            assistant: Assistant.defaultAssistants.first!,
            bookId: bookState.selectedBook?.id,
            model: "gemini-2.0-flash-exp",
            ragEnabled: true,
            summary: summary,
            history: recentMessages
        ) { [weak self] event in
            guard let self = self else { return }

            // 修复：在 Task 内部也使用 weak self 避免循环引用
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch event {
                case .content(let content):
                    Logger.info("💬 收到内容: \(content)")
                    // 逐步更新内容
                    self.streamingContent += content
                    if messageIndex < self.messages.count {
                        self.messages[messageIndex] = ChatMessage(
                            role: .assistant,
                            content: self.streamingContent
                        )
                    }

                case .error(let error):
                    if messageIndex < self.messages.count {
                        self.messages[messageIndex] = ChatMessage(
                            role: .assistant,
                            content: "❌ 错误: \(error)"
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
                
                self.isLoading = false
    
                switch result {
                case .failure(let error):
                    // 检查是否是用户主动取消
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        // 用户主动取消，标记消息
                        if messageIndex < self.messages.count {
                            let currentMessage = self.messages[messageIndex]
                            self.messages[messageIndex] = ChatMessage(
                                id: currentMessage.id,
                                role: currentMessage.role,
                                content: currentMessage.content,
                                timestamp: currentMessage.timestamp,
                                thinking: currentMessage.thinking,
                                sources: currentMessage.sources,
                                usage: currentMessage.usage,
                                systemPrompt: currentMessage.systemPrompt,
                                stoppedByUser: true
                            )
                        }
                        Logger.info("⏹️ 用户取消了请求")
                    } else {
                        // 真正的错误
                        if messageIndex < self.messages.count {
                            self.messages[messageIndex] = ChatMessage(
                                role: .assistant,
                                content: "❌ 请求失败: \(error.localizedDescription)"
                            )
                        }
                    }
                case .success:
                    // 流式完成，内容已经在事件中更新
                    // 保存助手消息到数据库
                    if messageIndex < self.messages.count {
                        let finalMessage = self.messages[messageIndex]
                        self.historyService?.saveMessage(finalMessage)
                        Logger.info("💾 保存助手回复到数据库")
                        
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
        
        let totalMessages = messages.count
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
        
        // 调用 AI 生成摘要（使用简单的非流式请求）
        // 这里简化实现，实际可以调用后端的摘要 API
        let summaryText = conversationText // 临时：直接使用对话文本
        
        // 保存摘要
        conversation.summary = summaryText
        conversation.summarizedMessageCount = summarizedCount + messagesToSummarize.count
        
        historyService?.saveSummary(summary: summaryText, messageCount: conversation.summarizedMessageCount)
        Logger.info("✅ 摘要已保存，已摘要消息数: \(conversation.summarizedMessageCount)")
    }
}
