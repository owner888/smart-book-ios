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
    
    /// 获取用户 Documents 目录中的 Books 文件夹路径
    var userBooksDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let booksPath = documentsPath.appendingPathComponent("Books")
        
        // 确保目录存在
        if !FileManager.default.fileExists(atPath: booksPath.path) {
            try? FileManager.default.createDirectory(at: booksPath, withIntermediateDirectories: true)
        }
        
        return booksPath
    }
    
    /// 获取书籍列表（合并 Bundle 和用户导入的书籍）
    func fetchBooks() async throws -> [Book] {
        // 加载所有本地书籍（Bundle + 用户导入）
        let localBooks = loadLocalBooks()
        if !localBooks.isEmpty {
            return localBooks
        }
        
        // 如果本地没有书籍，尝试从 API 获取
        return try await fetchBooksFromAPI()
    }
    
    /// 从本地加载所有 epub 书籍（Bundle + 用户导入）
    func loadLocalBooks() -> [Book] {
        var books: [Book] = []
        
        // 1. 从 Bundle 加载预置书籍
        books.append(contentsOf: loadBooksFromBundle())
        
        // 2. 从用户 Documents 目录加载导入的书籍
        books.append(contentsOf: loadBooksFromUserDocuments())
        
        return books.sorted { $0.title < $1.title }
    }
    
    /// 从 Bundle 加载预置书籍
    private func loadBooksFromBundle() -> [Book] {
        var books: [Book] = []
        
        // 从 Bundle 中查找 epub 文件
        guard let resourcePath = Bundle.main.resourcePath else {
            return books
        }
        
        let booksPath = (resourcePath as NSString).appendingPathComponent("Books")
        let fileManager = FileManager.default
        
        // 检查 Books 目录是否存在
        guard fileManager.fileExists(atPath: booksPath) else {
            // 尝试直接从 Bundle 根目录查找
            return loadBooksFromBundleRoot()
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: booksPath)
            for file in files {
                if file.hasSuffix(".epub") {
                    let filePath = (booksPath as NSString).appendingPathComponent(file)
                    if var book = createBook(from: file, path: filePath) {
                        book = Book(id: book.id, title: book.title, author: book.author, 
                                   coverURL: book.coverURL, filePath: book.filePath, 
                                   addedDate: book.addedDate)
                        books.append(book)
                    }
                }
            }
        } catch {
            print("Error loading bundle books: \(error)")
        }
        
        return books
    }
    
    /// 从用户 Documents 目录加载导入的书籍
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
            print("Error loading user books: \(error)")
        }
        
        return books
    }
    
    /// 导入书籍文件到用户 Documents 目录
    func importBook(from sourceURL: URL) throws -> Book {
        let fileManager = FileManager.default
        let filename = sourceURL.lastPathComponent
        let destinationURL = userBooksDirectory.appendingPathComponent(filename)
        
        // 如果文件已存在，先删除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // 开始访问安全作用域资源
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw APIError.custom("无法访问该文件")
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        // 复制文件到 Documents/Books 目录
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // 创建并返回 Book 对象
        guard let book = createBook(from: filename, path: destinationURL.path) else {
            throw APIError.custom("无法创建书籍")
        }
        
        return book
    }
    
    /// 删除用户导入的书籍
    func deleteBook(_ book: Book) throws {
        guard let filePath = book.filePath else {
            throw APIError.custom("书籍路径不存在")
        }
        
        // 只允许删除用户导入的书籍（在 Documents 目录中的）
        let fileURL = URL(fileURLWithPath: filePath)
        guard filePath.contains("Documents/Books") else {
            throw APIError.custom("只能删除用户导入的书籍")
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    /// 检查书籍是否为用户导入的（可删除）
    func isUserImportedBook(_ book: Book) -> Bool {
        guard let filePath = book.filePath else { return false }
        return filePath.contains("Documents/Books")
    }
    
    /// 从 Bundle 根目录查找 epub 文件
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
    
    /// 根据文件名创建 Book 对象（解析 EPUB 元数据）
    private func createBook(from filename: String, path: String) -> Book? {
        // 为书籍生成唯一 ID
        let id = filename.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
        
        // 从文件名提取默认书名（去除 .epub 扩展名）
        let defaultTitle = (filename as NSString).deletingPathExtension
        
        // 尝试解析 EPUB 元数据
        let metadata = EPUBParser.parseMetadataForiOS(from: path)
        
        // 使用解析的元数据，如果没有则使用默认值
        let title = metadata.title ?? defaultTitle
        let author = metadata.author ?? guessAuthor(for: defaultTitle)
        
        // 提取并缓存封面图片
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
    
    /// 根据书名猜测作者
    private func guessAuthor(for title: String) -> String {
        // 四大名著及常见书籍的作者映射
        let authorMap: [String: String] = [
            // 四大名著（公版书）
            "西游记": "吴承恩",
            "三国演义": "罗贯中",
            "水浒传": "施耐庵",
            "红楼梦": "曹雪芹"
        ]
        
        // 尝试精确匹配
        if let author = authorMap[title] {
            return author
        }
        
        // 尝试部分匹配（处理带校注本等后缀的书名）
        for (bookName, author) in authorMap {
            if title.contains(bookName) {
                return author
            }
        }
        
        // 尝试从文件名中提取作者（格式：书名(作者)）
        if let range = title.range(of: "\\(([^)]+)\\)", options: .regularExpression) {
            var authorPart = String(title[range])
            authorPart = authorPart.replacingOccurrences(of: "(", with: "")
            authorPart = authorPart.replacingOccurrences(of: ")", with: "")
            // 清理作者名
            if authorPart.contains("曹雪芹") { return "曹雪芹" }
            if authorPart.contains("罗贯中") { return "罗贯中" }
            if authorPart.contains("施耐庵") { return "施耐庵" }
            if authorPart.contains("吴承恩") { return "吴承恩" }
            return authorPart
        }
        
        return "未知作者"
    }
    
    /// 从 API 获取书籍列表
    func fetchBooksFromAPI() async throws -> [Book] {
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
