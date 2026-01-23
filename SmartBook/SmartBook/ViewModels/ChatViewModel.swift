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
    private let streamingService = StreamingChatService()
    private var streamingContent = ""
    
    func scrollToBottom() {
        withAnimation {
            scrollProxy?.scrollTo("bottomAnchor", anchor: .bottom)
        }
    }
    
    func stopAnswer() {
        
    }

    @MainActor
    func sendMessage(_ text: String) async {
        guard let bookState = bookState else { return }

        Logger.info("📤 发送消息: \(text)")
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        questionMessageId = userMessage.id

        isLoading = true
        streamingContent = ""

        // 创建一个临时的助手消息用于流式更新
        let streamingMessage = ChatMessage(role: .assistant, content: "")
        messages.append(streamingMessage)
        let messageIndex = messages.count - 1

        // 使用流式API
        streamingService.sendMessageStream(
            message: text,
            assistant: Assistant.defaultAssistants.first!,
            bookId: bookState.selectedBook?.id,
            model: "gemini-2.0-flash-exp",
            ragEnabled: true
        ) { [weak self] event in
            guard let self = self else { return }

            Task { @MainActor in
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

            Task { @MainActor in
                self.isLoading = false
    
                switch result {
                case .failure(let error):
                    if messageIndex < self.messages.count {
                        self.messages[messageIndex] = ChatMessage(
                            role: .assistant,
                            content: "❌ 请求失败: \(error.localizedDescription)"
                        )
                    }
                case .success:
                    // 流式完成，内容已经在事件中更新
                    break
                }
            }
        }
    }

    func clearMessages() {
        messages.removeAll()
    }
}
