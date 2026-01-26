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

        // 获取历史消息上下文（最近10条消息）
        let recentMessages = Array(messages.suffix(10))
        
        // 使用流式API
        streamingService.sendMessageStream(
            message: text,
            assistant: Assistant.defaultAssistants.first!,
            bookId: bookState.selectedBook?.id,
            model: "gemini-2.0-flash-exp",
            ragEnabled: true,
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
}
