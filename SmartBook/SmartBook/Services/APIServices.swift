// APIServices.swift - API 服务（连接 PHP 后端）

import Foundation

// MARK: - Chat Service
class ChatService {
    
    func sendMessage(_ text: String, bookId: String?, history: [ChatMessage]) async throws -> String {
        let url = URL(string: "\(AppState.apiBaseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        var body: [String: Any] = [
            "message": text,
            "history": history.map { msg in
                ["role": msg.role.rawValue, "content": msg.content]
            }
        ]
        
        if let bookId = bookId {
            body["book_id"] = bookId
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        if let error = chatResponse.error {
            throw APIError.custom(error)
        }
        
        return chatResponse.response ?? ""
    }
}

// MARK: - Book Service
class BookService {
    
    func fetchBooks() async throws -> [Book] {
        let url = URL(string: "\(AppState.apiBaseURL)/api/books")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let booksResponse = try JSONDecoder().decode(BooksResponse.self, from: data)
        
        if let error = booksResponse.error {
            throw APIError.custom(error)
        }
        
        return booksResponse.books ?? []
    }
    
    func searchBook(_ bookId: String, query: String) async throws -> [SearchResult] {
        let url = URL(string: "\(AppState.apiBaseURL)/api/books/\(bookId)/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.results ?? []
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
