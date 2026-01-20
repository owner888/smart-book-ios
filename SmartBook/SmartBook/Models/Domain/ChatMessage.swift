//
//  ChatMessage.swift
//  SmartBook
//
//  Created by kaka on 20/1/26.
//

import Foundation

// MARK: - 聊天消息模型
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    var thinking: String?
    var sources: [RAGSource]?
    var usage: UsageInfo?
    var systemPrompt: String?
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), thinking: String? = nil, sources: [RAGSource]? = nil, usage: UsageInfo? = nil, systemPrompt: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.thinking = thinking
        self.sources = sources
        self.usage = usage
        self.systemPrompt = systemPrompt
    }
}