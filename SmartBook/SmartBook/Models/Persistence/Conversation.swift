//
//  ConversationModel.swift
//  SmartBook
//
//  Created by kaka on 20/1/26.
//

import SwiftData
import Foundation

@Model
class Conversation {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // 关联的书籍ID（可选）
    var bookId: UUID?
    var bookTitle: String?
    
    // 上下文摘要（用于压缩历史对话）
    var summary: String?
    var summarizedMessageCount: Int = 0

    @Relationship(deleteRule: .cascade)
    var messages: [Message]? = []

    init(
        id: UUID = UUID(),
        title: String,
        bookId: UUID? = nil,
        bookTitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.bookId = bookId
        self.bookTitle = bookTitle
    }
    
    // 转换为 ChatConversation
    func toChatConversation() -> ChatConversation {
        return ChatConversation(
            id: id,
            title: title,
            createdAt: createdAt
        )
    }
    
    // 更新时间戳
    func touch() {
        updatedAt = Date()
    }
    
    // 生成摘要标题（从第一条消息内容）
    func generateTitle(from firstMessage: String) {
        let maxLength = 30
        let trimmed = firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > maxLength {
            title = String(trimmed.prefix(maxLength)) + "..."
        } else {
            title = trimmed.isEmpty ? "新对话" : trimmed
        }
    }
}
