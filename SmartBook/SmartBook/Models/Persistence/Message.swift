//
//  MessageModel.swift
//  SmartBook
//
//  Created by kaka on 20/1/26.
//
import SwiftData
import Foundation

@Model
class Message {
    var id: UUID = UUID()
    var role: Role?
    var content: String = ""
    var createdAt: Date = Date()
    
    // 扩展字段以匹配 ChatMessage
    var thinking: String?
    var sourcesData: Data?  // JSON 序列化的 [RAGSource]
    var usageData: Data?    // JSON 序列化的 UsageInfo
    var systemPrompt: String?
    var stoppedByUser: Bool = false

    var conversation: Conversation?

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date = Date(),
        thinking: String? = nil,
        sourcesData: Data? = nil,
        usageData: Data? = nil,
        systemPrompt: String? = nil,
        stoppedByUser: Bool = false,
        conversation: Conversation? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.thinking = thinking
        self.sourcesData = sourcesData
        self.usageData = usageData
        self.systemPrompt = systemPrompt
        self.stoppedByUser = stoppedByUser
        self.conversation = conversation
    }
    
    // 从 ChatMessage 创建
    convenience init(from chatMessage: ChatMessage, conversation: Conversation?) {
        let sourcesData = try? JSONEncoder().encode(chatMessage.sources)
        let usageData = try? JSONEncoder().encode(chatMessage.usage)
        
        self.init(
            id: chatMessage.id,
            role: chatMessage.role,
            content: chatMessage.content,
            createdAt: chatMessage.timestamp,
            thinking: chatMessage.thinking,
            sourcesData: sourcesData,
            usageData: usageData,
            systemPrompt: chatMessage.systemPrompt,
            stoppedByUser: chatMessage.stoppedByUser ?? false,
            conversation: conversation
        )
    }
    
    // 转换为 ChatMessage
    func toChatMessage() -> ChatMessage {
        let sources = sourcesData.flatMap { try? JSONDecoder().decode([RAGSource].self, from: $0) }
        let usage = usageData.flatMap { try? JSONDecoder().decode(UsageInfo.self, from: $0) }
        
        return ChatMessage(
            id: id,
            role: role ?? .user,
            content: content,
            timestamp: createdAt,
            thinking: thinking,
            sources: sources,
            usage: usage,
            systemPrompt: systemPrompt,
            stoppedByUser: stoppedByUser ? true : nil
        )
    }
}
