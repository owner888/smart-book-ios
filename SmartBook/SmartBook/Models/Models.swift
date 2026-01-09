// Models.swift - 数据模型

import Foundation

// MARK: - 书籍模型
struct Book: Identifiable, Codable {
    let id: String
    let title: String
    let author: String
    let coverURL: String?
    let filePath: String?
    let addedDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, author
        case coverURL = "cover_url"
        case filePath = "file_path"
        case addedDate = "added_date"
    }
}

// MARK: - 聊天消息模型
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - API 响应模型
struct ChatResponse: Codable {
    let response: String?
    let error: String?
    let usage: UsageInfo?
}

struct UsageInfo: Codable {
    let tokens: TokenInfo?
    let cost: Double?
    let model: String?
}

struct TokenInfo: Codable {
    let input: Int?
    let output: Int?
    let total: Int?
}

struct BooksResponse: Codable {
    let books: [Book]?
    let error: String?
}

// MARK: - 设置模型
struct AppSettings: Codable {
    var apiBaseURL: String
    var selectedModel: String
    var autoTTS: Bool
    var ttsVoice: String?
    var ttsRate: Double
    
    static let `default` = AppSettings(
        apiBaseURL: "http://localhost:8080",
        selectedModel: "gemini-2.5-flash",
        autoTTS: true,
        ttsVoice: nil,
        ttsRate: 1.0
    )
}
