// AssistantModels.swift - 助手相关模型

import Foundation
import SwiftUI

// MARK: - 助手配置
struct Assistant: Identifiable, Codable {
    let id: String
    let name: String
    let avatar: String
    let color: String
    let description: String
    let systemPrompt: String
    let action: AssistantAction
    let useRAG: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, avatar, color, description
        case systemPrompt = "system_prompt"
        case action
        case useRAG = "use_rag"
    }
    
    var colorValue: Color {
        Color(hex: color) ?? .green
    }
    
    init(id: String, name: String, avatar: String, color: String, description: String, systemPrompt: String, action: AssistantAction, useRAG: Bool = false) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.color = color
        self.description = description
        self.systemPrompt = systemPrompt
        self.action = action
        self.useRAG = useRAG
    }
}

enum AssistantAction: String, Codable {
    case ask
    case continueWriting = "continue"
    case chat
}

// MARK: - 默认助手配置
extension Assistant {
    static let defaultAssistants: [Assistant] = [
        Assistant(
            id: "chat",
            name: "通用聊天",
            avatar: "💬",
            color: "#2196f3",
            description: "我是通用聊天助手，可以与您讨论各种话题",
            systemPrompt: "你是一个友好的AI助手，可以与用户讨论各种话题。",
            action: .chat,
            useRAG: false
        ),
        Assistant(
            id: "book",
            name: "书籍问答",
            avatar: "📚",
            color: "#4caf50",
            description: "我是书籍问答助手，可以帮助您理解和分析书籍内容",
            systemPrompt: "你是一个专业的书籍问答助手，能够帮助用户理解和分析书籍内容。",
            action: .ask,
            useRAG: true
        ),
        Assistant(
            id: "continue",
            name: "续写小说",
            avatar: "✍️",
            color: "#ff9800",
            description: "我是小说续写助手，可以根据书籍风格继续创作",
            systemPrompt: "你是一个专业的小说续写助手，能够模仿书籍的写作风格进行续写。",
            action: .continueWriting,
            useRAG: false
        )
    ]
}


// MARK: - RAG 检索来源
struct RAGSource: Codable, Identifiable {
    let id: UUID
    let text: String
    let score: Double
    let chapterTitle: String?
    let chapterIndex: Int?
    
    enum CodingKeys: String, CodingKey {
        case text, score
        case chapterTitle = "chapter_title"
        case chapterIndex = "chapter_index"
    }
    
    init(id: UUID = UUID(), text: String, score: Double, chapterTitle: String? = nil, chapterIndex: Int? = nil) {
        self.id = id
        self.text = text
        self.score = score
        self.chapterTitle = chapterTitle
        self.chapterIndex = chapterIndex
    }
    
    // 自定义解码（id 在客户端生成）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.text = try container.decode(String.self, forKey: .text)
        self.score = try container.decode(Double.self, forKey: .score)
        self.chapterTitle = try container.decodeIfPresent(String.self, forKey: .chapterTitle)
        self.chapterIndex = try container.decodeIfPresent(Int.self, forKey: .chapterIndex)
    }
    
    // 自定义编码（不编码 id）
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(score, forKey: .score)
        try container.encodeIfPresent(chapterTitle, forKey: .chapterTitle)
        try container.encodeIfPresent(chapterIndex, forKey: .chapterIndex)
    }
    
    var scorePercentage: Int {
        Int(score * 100)
    }
}

// MARK: - AI 模型配置
struct AIModel: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let provider: String
    let rate: String  // 价格比率，如 "0x", "0.33x", "1x"
    let description: String?  // 模型描述
    let maxTokens: Int?
    let costPer1MInput: Double?
    let costPer1MOutput: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, provider, rate, description
        case maxTokens = "max_tokens"
        case costPer1MInput = "cost_per_1m_input"
        case costPer1MOutput = "cost_per_1m_output"
    }
    
    var displayName: String {
        name
    }
    
    // Equatable conformance - 根据 id 比较
    static func == (lhs: AIModel, rhs: AIModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 默认模型
extension AIModel {
    static let defaultModels: [AIModel] = [
        AIModel(id: "gemini-2.0-flash-exp", name: "Gemini 2.0 Flash", provider: "Google", rate: "0x", description: "Free experimental model", maxTokens: 1000000, costPer1MInput: 0, costPer1MOutput: 0),
        AIModel(id: "gemini-2.0-flash-thinking-exp-01-21", name: "Gemini 2.0 Flash Thinking", provider: "Google", rate: "0x", description: "Free thinking model", maxTokens: 32000, costPer1MInput: 0, costPer1MOutput: 0),
        AIModel(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", provider: "Google", rate: "1x", description: "Expert model", maxTokens: 2000000, costPer1MInput: 1.25, costPer1MOutput: 5.0),
        AIModel(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", provider: "Google", rate: "0.33x", description: "Fast model", maxTokens: 1000000, costPer1MInput: 0.075, costPer1MOutput: 0.30),
        AIModel(id: "gpt-4o", name: "GPT-4o", provider: "OpenAI", rate: "2x", description: "OpenAI premium", maxTokens: 128000, costPer1MInput: 2.5, costPer1MOutput: 10.0),
        AIModel(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: "OpenAI", rate: "0.5x", description: "OpenAI budget", maxTokens: 128000, costPer1MInput: 0.15, costPer1MOutput: 0.60),
    ]
}
