//
//  ChatHistoryService.swift
//  SmartBook
//
//  Created by kaka on 26/1/26.
//

import Combine
import Foundation
import SwiftData

/// 聊天历史管理服务
@MainActor
class ChatHistoryService: ObservableObject {
    private let modelContext: ModelContext

    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadConversations()
    }

    // MARK: - 对话管理

    /// 创建新对话
    func createConversation(title: String? = nil, bookId: UUID? = nil, bookTitle: String? = nil) -> Conversation {
        let conversationTitle = title ?? L("chatHistory.newChat")
        let conversation = Conversation(
            title: conversationTitle,
            bookId: bookId,
            bookTitle: bookTitle
        )
        modelContext.insert(conversation)
        saveContext()

        currentConversation = conversation
        loadConversations()

        Logger.info("✅ 创建新对话: \(conversationTitle)")
        return conversation
    }

    /// 加载所有对话（按更新时间倒序）
    func loadConversations() {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            conversations = try modelContext.fetch(descriptor)
            Logger.info("📚 加载了 \(conversations.count) 个历史对话")
        } catch {
            Logger.error("❌ 加载对话失败: \(error)")
            conversations = []
        }
    }

    /// 切换到指定对话
    func switchToConversation(_ conversation: Conversation) {
        currentConversation = conversation
        Logger.info("🔄 切换到对话: \(conversation.title)")
    }

    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        modelContext.delete(conversation)
        saveContext()

        if currentConversation?.id == conversation.id {
            currentConversation = nil
        }

        loadConversations()
        Logger.info("🗑️ 删除对话: \(conversation.title)")
    }

    /// 重命名对话
    func renameConversation(_ conversation: Conversation, newTitle: String) {
        conversation.title = newTitle
        conversation.touch()
        saveContext()
        loadConversations()
        Logger.info("✏️ 重命名对话: \(newTitle)")
    }

    /// 清空所有对话
    func clearAllConversations() {
        for conversation in conversations {
            conversation.messages?.forEach { modelContext.delete($0) }
            modelContext.delete(conversation)
        }
        saveContext()

        currentConversation = nil
        loadConversations()
        Logger.info("🧹 清空所有对话")
    }

    /// 清空当前对话的消息
    func clearCurrentConversationMessages() {
        guard let conversation = currentConversation else { return }

        conversation.messages?.forEach { modelContext.delete($0) }
        conversation.messages = []
        conversation.touch()
        saveContext()

        Logger.info("🧹 清空对话消息: \(conversation.title)")
    }

    // MARK: - 消息管理

    /// 保存消息到当前对话
    func saveMessage(_ chatMessage: ChatMessage) {
        var conversation = currentConversation

        // 如果没有当前对话且是用户消息，自动创建新对话
        if conversation == nil && chatMessage.role == .user {
            // 使用第一条用户消息作为标题
            conversation = Conversation(title: L("chatHistory.newChat"))
            conversation!.generateTitle(from: chatMessage.content)
            modelContext.insert(conversation!)
            currentConversation = conversation
            Logger.info("✅ 自动创建新对话: \(conversation!.title)")
        }

        guard let conversation = conversation else {
            Logger.info("⚠️ 没有当前对话且不是用户消息，跳过保存")
            return
        }

        let message = Message(from: chatMessage, conversation: conversation)
        modelContext.insert(message)

        // 更新对话时间
        conversation.touch()

        saveContext()

        // 保存后重新加载对话列表
        loadConversations()

        Logger.info("💾 保存消息到对话: \(conversation.title)")
    }

    /// 保存多条消息
    func saveMessages(_ chatMessages: [ChatMessage]) {
        for message in chatMessages {
            saveMessage(message)
        }
    }

    /// 加载当前对话的所有消息
    func loadMessages() -> [ChatMessage] {
        guard let conversation = currentConversation,
            let messages = conversation.messages
        else {
            return []
        }

        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        return sorted.map { $0.toChatMessage() }
    }

    // MARK: - 摘要管理

    /// 保存对话摘要
    func saveSummary(summary: String, messageCount: Int) {
        guard let conversation = currentConversation else { return }

        conversation.summary = summary
        conversation.summarizedMessageCount = messageCount
        conversation.touch()
        saveContext()

        Logger.info("💾 保存摘要: 已摘要\(messageCount)条消息")
    }

    // MARK: - 私有方法

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            Logger.error("❌ 保存上下文失败: \(error)")
        }
    }
}
