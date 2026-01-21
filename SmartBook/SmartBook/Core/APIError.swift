// APIError.swift - API 错误定义

import Foundation

// MARK: - API 错误
enum APIError: LocalizedError {
    case serverError
    case networkError
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .serverError:
            return "服务器错误"
        case .networkError:
            return "网络连接失败"
        case .custom(let message):
            return message
        }
    }
}

// MARK: - 搜索结果模型
struct SearchResult: Codable, Identifiable {
    var id: String { "\(chapterIndex)-\(score)" }
    let content: String
    let chapterTitle: String?
    let chapterIndex: Int
    let score: Double
    
    enum CodingKeys: String, CodingKey {
        case content
        case chapterTitle = "chapter_title"
        case chapterIndex = "chapter_index"
        case score
    }
}

struct SearchResponse: Codable {
    let results: [SearchResult]?
    let error: String?
}
