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
    var isFavorite: Bool
    var currentChapter: Int
    var totalChapters: Int
    var currentPage: Int
    var totalPages: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, author
        case coverURL = "cover_url"
        case filePath = "file_path"
        case addedDate = "added_date"
        case isFavorite = "is_favorite"
        case currentChapter = "current_chapter"
        case totalChapters = "total_chapters"
        case currentPage = "current_page"
        case totalPages = "total_pages"
    }
    
    init(id: String, title: String, author: String, coverURL: String?, filePath: String?, addedDate: Date?, isFavorite: Bool = false, currentChapter: Int = 0, totalChapters: Int = 0, currentPage: Int = 0, totalPages: Int = 0) {
        self.id = id
        self.title = title
        self.author = author
        self.coverURL = coverURL
        self.filePath = filePath
        self.addedDate = addedDate
        self.isFavorite = isFavorite
        self.currentChapter = currentChapter
        self.totalChapters = totalChapters
        self.currentPage = currentPage
        self.totalPages = totalPages
    }
    
    // 计算阅读进度百分比
    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
    
    // 进度文本：第X页 或 第X章
    var progressText: String {
        if totalPages > 0 && currentPage > 0 {
            return "\(currentPage)/\(totalPages)"
        } else if totalChapters > 0 && currentChapter > 0 {
            return String(format: L("reader.chapterIndicator"), currentChapter, totalChapters)
        } else {
            return L("home.readProgress")
        }
    }
}

// MARK: - 阅读统计模型
struct ReadingStats: Codable {
    var totalBooksRead: Int = 0
    var totalMinutesRead: Int = 0
    var currentStreak: Int = 0
    var todayMinutes: Int = 0
    var lastReadDate: Date?
    
    var formattedTotalTime: String {
        let hours = totalMinutesRead / 60
        let minutes = totalMinutesRead % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var formattedTodayTime: String {
        let minutes = todayMinutes
        return "\(minutes) min"
    }
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

struct SelectBookResponse: Codable {
    let success: Bool?
    let message: String?
    let error: String?
    let book: String?
    let contextCache: ContextCacheStatus?
}

struct ContextCacheStatus: Codable {
    let exists: Bool?
    let created: Bool?
    let tokenCount: Int?
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
        apiBaseURL: AppConfig.DefaultValues.apiBaseURL,
        selectedModel: "gemini-2.5-flash",
        autoTTS: AppConfig.DefaultValues.autoTTS,
        ttsVoice: nil,
        ttsRate: AppConfig.DefaultValues.ttsRate
    )
}
