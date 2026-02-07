// BookService.swift - 书籍服务

import Foundation

// 使用 APIError.swift 中定义的 SearchResult
typealias BookSearchResult = SearchResult

@Observable
class BookService {
    private let readingStatsKey = "reading_stats"
    
    // MARK: - 分页加载缓存
    private var cachedBooks: [Book] = []
    private var isCacheValid = false
    private let cacheQueue = DispatchQueue(label: "com.smartbook.bookservice.cache")
    
    var userBooksDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let booksPath = documentsPath.appendingPathComponent("Books")
        
        if !FileManager.default.fileExists(atPath: booksPath.path) {
            try? FileManager.default.createDirectory(at: booksPath, withIntermediateDirectories: true)
        }
        
        return booksPath
    }
    
    // MARK: - 书籍获取
    
    func fetchBooks() async throws -> [Book] {
        let localBooks = loadLocalBooks()
        if !localBooks.isEmpty {
            return localBooks
        }
        return try await fetchBooksFromAPI()
    }
    
    // MARK: - 分页加载优化
    
    /// 分页加载书籍
    /// - Parameters:
    ///   - page: 页码（从0开始）
    ///   - pageSize: 每页数量，默认20本
    /// - Returns: 当前页的书籍列表
    func loadBooks(page: Int, pageSize: Int = 20) async -> [Book] {
        // 确保缓存已加载
        await ensureCacheLoaded()
        
        return await cacheQueue.sync {
            let startIndex = page * pageSize
            let endIndex = min(startIndex + pageSize, cachedBooks.count)
            
            guard startIndex < cachedBooks.count else {
                return []
            }
            
            return Array(cachedBooks[startIndex..<endIndex])
        }
    }
    
    /// 获取总书籍数量
    func getTotalBooksCount() async -> Int {
        await ensureCacheLoaded()
        return await cacheQueue.sync {
            cachedBooks.count
        }
    }
    
    /// 检查是否还有更多书籍
    /// - Parameters:
    ///   - page: 当前页码
    ///   - pageSize: 每页数量
    /// - Returns: 是否有更多书籍
    func hasMoreBooks(page: Int, pageSize: Int = 20) async -> Bool {
        let total = await getTotalBooksCount()
        return (page + 1) * pageSize < total
    }
    
    /// 刷新缓存
    func refreshCache() {
        cacheQueue.sync {
            isCacheValid = false
            cachedBooks.removeAll()
        }
    }
    
    /// 确保缓存已加载
    private func ensureCacheLoaded() async {
        let needsLoad = await cacheQueue.sync {
            !isCacheValid
        }
        
        if needsLoad {
            let books = loadLocalBooks()
            await cacheQueue.sync {
                cachedBooks = books
                isCacheValid = true
            }
        }
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
    
    // MARK: - 书籍导入与删除
    
    func importBook(from sourceURL: URL) throws -> Book {
        let fileManager = FileManager.default
        let filename = sourceURL.lastPathComponent
        let destinationURL = userBooksDirectory.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw MediaError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        guard let book = createBook(from: filename, path: destinationURL.path) else {
            throw BookError.corrupted
        }
        
        return book
    }
    
    func deleteBook(_ book: Book) throws {
        guard let filePath = book.filePath else {
            throw BookError.notFound
        }
        
        guard filePath.contains("Documents/Books") else {
            throw BookError.cannotDeleteBundled
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
    
    // MARK: - 书籍创建
    
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
    
    // MARK: - API 调用
    
    func fetchBooksFromAPI() async throws -> [Book] {
        // ✅ 使用 HTTPClient 统一请求
        let (data, httpResponse) = try await HTTPClient.shared.get("/api/books")
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.from(statusCode: httpResponse.statusCode)
        }
        
        let booksResponse = try HTTPClient.shared.decode(BooksResponse.self, from: data)
        
        if let error = booksResponse.error {
            throw APIError.custom(error)
        }
        
        return booksResponse.books ?? []
    }
    
    func searchBook(_ bookId: String, query: String) async throws -> [SearchResult] {
        Logger.debug("Searching in book \(bookId) for: \(query)")
        
        // ✅ 使用 HTTPClient 统一请求
        let (data, httpResponse) = try await HTTPClient.shared.post(
            "/api/books/\(bookId)/search",
            body: ["query": query]
        )
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.from(statusCode: httpResponse.statusCode)
        }
        
        let searchResponse = try HTTPClient.shared.decode(SearchResponse.self, from: data)
        return searchResponse.results ?? []
    }
    
    // MARK: - 书籍选择
    
    /// 选择书籍（通知后端）
    func selectBook(_ book: Book, onProgress: ((Double) -> Void)? = nil) async throws {
        // 从书籍路径中提取文件名
        guard let filePath = book.filePath else {
            throw BookError.notFound
        }
        
        let filename = URL(fileURLWithPath: filePath).lastPathComponent
        
        do {
            // ✅ 使用 HTTPClient 发送请求
            let (data, httpResponse) = try await HTTPClient.shared.post(
                "/api/books/select",
                body: ["book": filename]
            )
            
            // 如果是 404，说明服务器没有这本书，需要上传
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 500 {
                Logger.info("📤 服务器没有该书籍，开始上传: \(filename)")
                try await uploadBook(filePath: filePath, onProgress: onProgress)
                
                // 上传成功后重新选择
                let (data2, httpResponse2) = try await HTTPClient.shared.post(
                    "/api/books/select",
                    body: ["book": filename]
                )
                
                guard httpResponse2.statusCode == 200 else {
                    throw APIError.from(statusCode: httpResponse2.statusCode)
                }
                
                let result = try HTTPClient.shared.decode(SelectBookResponse.self, from: data2)
                if let error = result.error {
                    throw APIError.custom(error)
                }
                
                Logger.info("✅ 书籍已选择（上传后）: \(filename)")
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.from(statusCode: httpResponse.statusCode)
            }
            
            // 解析响应
            let result = try HTTPClient.shared.decode(SelectBookResponse.self, from: data)
            if let error = result.error {
                throw APIError.custom(error)
            }
            
            Logger.info("✅ 书籍已选择: \(filename)")
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.custom("选择书籍失败: \(error.localizedDescription)")
        }
    }
    
    /// 上传书籍到服务器
    private func uploadBook(filePath: String, onProgress: ((Double) -> Void)?) async throws {
        let fileURL = URL(fileURLWithPath: filePath)
        let filename = fileURL.lastPathComponent
        
        Logger.info("📤 准备上传书籍: \(filename)")
        
        let fileData = try Data(contentsOf: fileURL)
        Logger.info("📦 文件大小: \(fileData.count / 1024) KB")
        Logger.info("🚀 开始上传...")
        
        do {
            // ✅ 使用 HTTPClient 上传文件
            let (data, httpResponse) = try await HTTPClient.shared.upload(
                "/api/books/upload",
                fileData: fileData,
                filename: filename,
                onProgress: onProgress
            )
            
            Logger.info("📡 响应状态码: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                if let errorText = String(data: data, encoding: .utf8) {
                    Logger.error("❌ 服务器错误响应: \(errorText)")
                }
                throw APIError.from(statusCode: httpResponse.statusCode)
            }
            
            let result = try HTTPClient.shared.decode(UploadResponse.self, from: data)
            if result.success != true {
                Logger.error("❌ 上传失败: \(result.error ?? "未知错误")")
                throw BookError.uploadFailed
            }
            
            Logger.info("✅ 书籍上传成功: \(filename)")
            
        } catch let error as APIError {
            throw error
        } catch let error as BookError {
            throw error
        } catch {
            Logger.error("❌ 上传异常: \(error.localizedDescription)")
            throw BookError.uploadFailed
        }
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

// MARK: - 上传响应模型
struct UploadResponse: Codable {
    let success: Bool?
    let message: String?
    let error: String?
    let file: String?
    let existed: Bool?
}
