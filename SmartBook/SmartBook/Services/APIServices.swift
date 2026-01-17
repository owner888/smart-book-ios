// APIServices.swift - API 服务（连接 PHP 后端）

import Foundation

// MARK: - Chat Service
class ChatService {
    
    func sendMessage(_ text: String, bookId: String?, history: [ChatMessage]) async throws -> String {
        let url = URL(string: "\(AppConfig.apiBaseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
@Observable
class BookService {
    private let readingStatsKey = "reading_stats"
    
    var userBooksDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let booksPath = documentsPath.appendingPathComponent("Books")
        
        if !FileManager.default.fileExists(atPath: booksPath.path) {
            try? FileManager.default.createDirectory(at: booksPath, withIntermediateDirectories: true)
        }
        
        return booksPath
    }
    
    func fetchBooks() async throws -> [Book] {
        let localBooks = loadLocalBooks()
        if !localBooks.isEmpty {
            return localBooks
        }
        return try await fetchBooksFromAPI()
    }
    
    func loadLocalBooks() -> [Book] {
        var books: [Book] = []
        books.append(contentsOf: loadBooksFromBundle())
        books.append(contentsOf: loadBooksFromUserDocuments())
        // 加载阅读进度
        for i in 0..<books.count {
            let book = books[i]
            if let progress = ReadingProgress.load(for: book.id) {
                books[i] = Book(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    coverURL: book.coverURL,
                    filePath: book.filePath,
                    addedDate: book.addedDate,
                    isFavorite: book.isFavorite,
                    currentChapter: progress.chapterIndex,
                    totalChapters: 0,
                    currentPage: progress.pageIndex,
                    totalPages: 0
                )
            }
        }
        return books.sorted { $0.title < $1.title }
    }
    
    private func loadBooksFromBundle() -> [Book] {
        var books: [Book] = []
        
        guard let resourcePath = Bundle.main.resourcePath else {
            return books
        }
        
        let booksPath = (resourcePath as NSString).appendingPathComponent("Books")
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: booksPath) else {
            return loadBooksFromBundleRoot()
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: booksPath)
            for file in files {
                if file.hasSuffix(".epub") {
                    let filePath = (booksPath as NSString).appendingPathComponent(file)
                    if let book = createBook(from: file, path: filePath) {
                        books.append(book)
                    }
                }
            }
        } catch {
            Logger.error("Error loading bundle books: \(error)")
        }
        
        return books
    }
    
    private func loadBooksFromUserDocuments() -> [Book] {
        var books: [Book] = []
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: userBooksDirectory.path)
            for file in files {
                if file.hasSuffix(".epub") {
                    let filePath = userBooksDirectory.appendingPathComponent(file).path
                    if let book = createBook(from: file, path: filePath) {
                        books.append(book)
                    }
                }
            }
        } catch {
            Logger.error("Error loading user books: \(error)")
        }
        
        return books
    }
    
    func importBook(from sourceURL: URL) throws -> Book {
        let fileManager = FileManager.default
        let filename = sourceURL.lastPathComponent
        let destinationURL = userBooksDirectory.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw APIError.custom("无法访问该文件")
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        guard let book = createBook(from: filename, path: destinationURL.path) else {
            throw APIError.custom("无法创建书籍")
        }
        
        return book
    }
    
    func deleteBook(_ book: Book) throws {
        guard let filePath = book.filePath else {
            throw APIError.custom("书籍路径不存在")
        }
        
        guard filePath.contains("Documents/Books") else {
            throw APIError.custom("只能删除用户导入的书籍")
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    func isUserImportedBook(_ book: Book) -> Bool {
        guard let filePath = book.filePath else { return false }
        return filePath.contains("Documents/Books")
    }
    
    private func loadBooksFromBundleRoot() -> [Book] {
        var books: [Book] = []
        
        if let urls = Bundle.main.urls(forResourcesWithExtension: "epub", subdirectory: nil) {
            for url in urls {
                let filename = url.lastPathComponent
                if let book = createBook(from: filename, path: url.path) {
                    books.append(book)
                }
            }
        }
        
        return books.sorted { $0.title < $1.title }
    }
    
    private func createBook(from filename: String, path: String) -> Book? {
        let id = filename.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
        let defaultTitle = (filename as NSString).deletingPathExtension
        let metadata = EPUBParser.parseMetadataForiOS(from: path)
        
        let title = metadata.title ?? defaultTitle
        let author = metadata.author ?? guessAuthor(for: defaultTitle)
        
        var coverURL: String? = nil
        if let cachedCoverPath = EPUBParser.getCachedCoverPath(for: id) {
            coverURL = cachedCoverPath.absoluteString
        } else if let newCoverPath = EPUBParser.extractAndCacheCover(from: path, bookId: id) {
            coverURL = newCoverPath.absoluteString
        }
        
        return Book(
            id: id,
            title: title,
            author: author,
            coverURL: coverURL,
            filePath: path,
            addedDate: Date()
        )
    }
    
    private func guessAuthor(for title: String) -> String {
        let authorMap: [String: String] = [
            "西游记": "吴承恩",
            "三国演义": "罗贯中",
            "水浒传": "施耐庵",
            "红楼梦": "曹雪芹"
        ]
        
        if let author = authorMap[title] {
            return author
        }
        
        for (bookName, author) in authorMap {
            if title.contains(bookName) {
                return author
            }
        }
        
        if let range = title.range(of: "\\(([^)]+)\\)", options: .regularExpression) {
            var authorPart = String(title[range])
            authorPart = authorPart.replacingOccurrences(of: "(", with: "")
            authorPart = authorPart.replacingOccurrences(of: ")", with: "")
            return authorPart
        }
        
        return "未知作者"
    }
    
    func fetchBooksFromAPI() async throws -> [Book] {
        let url = URL(string: "\(AppConfig.apiBaseURL)/api/books")!
        
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
        let url = URL(string: "\(AppConfig.apiBaseURL)/api/books/\(bookId)/search")!
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
    
    // MARK: - 阅读统计功能
    
    func loadReadingStats() -> ReadingStats {
        guard let data = UserDefaults.standard.data(forKey: readingStatsKey),
              let stats = try? JSONDecoder().decode(ReadingStats.self, from: data) else {
            return ReadingStats()
        }
        
        if let lastRead = stats.lastReadDate {
            let calendar = Calendar.current
            if !calendar.isDateInToday(lastRead) {
                var newStats = stats
                newStats.todayMinutes = 0
                return newStats
            }
        }
        
        return stats
    }
    
    func updateReadingProgress(bookId: String, progress: Double) {
        updateReadingStats(minutes: 1)
    }
    
    private func updateReadingStats(minutes: Int) {
        var stats = loadReadingStats()
        stats.totalMinutesRead += minutes
        stats.todayMinutes += minutes
        stats.lastReadDate = Date()
        
        if let lastRead = stats.lastReadDate {
            let calendar = Calendar.current
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
               lastRead < yesterday {
                stats.currentStreak = 1
            } else if !calendar.isDateInToday(lastRead) {
                stats.currentStreak += 1
            }
        } else {
            stats.currentStreak = 1
        }
        
        let books = loadLocalBooks()
        stats.totalBooksRead = books.filter { $0.progressPercentage > 0.9 }.count
        
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: readingStatsKey)
        }
    }
    
    func toggleFavorite(_ book: Book) {
        // 暂不支持
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
