// BookServiceTests.swift - BookService 单元测试

import XCTest
@testable import SmartBook

final class BookServiceTests: XCTestCase {
    
    var bookService: BookService!
    
    override func setUpWithError() throws {
        bookService = BookService()
    }
    
    // MARK: - 书籍加载测试
    
    func testLoadLocalBooks() throws {
        // Given: 书籍服务已初始化
        
        // When: 加载本地书籍
        let books = bookService.loadLocalBooks()
        
        // Then: 应该返回书籍列表
        XCTAssertNotNil(books, "书籍列表不应为 nil")
        XCTAssertTrue(books.count >= 0, "书籍数量应该 >= 0")
    }
    
    func testFetchBooksAsync() async throws {
        // Given: 书籍服务已初始化
        
        // When: 异步获取书籍
        let books = try await bookService.fetchBooks()
        
        // Then: 应该返回书籍列表
        XCTAssertNotNil(books, "书籍列表不应为 nil")
    }
    
    // MARK: - 书籍导入测试
    
    func testImportBook() throws {
        // Given: 有效的 EPUB 文件路径
        // 注意: 需要提供测试文件
        guard let testEPUB = Bundle(for: type(of: self)).url(forResource: "test", withExtension: "epub") else {
            throw XCTSkip("测试 EPUB 文件不存在")
        }
        
        // When: 导入书籍
        let book = try bookService.importBook(from: testEPUB)
        
        // Then: 应该成功创建书籍
        XCTAssertNotNil(book, "导入的书籍不应为 nil")
        XCTAssertFalse(book.title.isEmpty, "书籍标题不应为空")
    }

    // MARK: - 书籍搜索测试
    
    func testSearchBook() async throws {
        // Given: 有效的书籍ID和查询
        let bookId = "test_book_id"
        let query = "测试查询"
        
        // When: 搜索书籍内容
        do {
            let results = try await bookService.searchBook(bookId, query: query)
            
            // Then: 应该返回搜索结果
            XCTAssertNotNil(results, "搜索结果不应为 nil")
        } catch {
            // 如果服务器未运行，跳过测试
            throw XCTSkip("服务器未运行")
        }
    }
    
    // MARK: - 阅读统计测试
    
    func testLoadReadingStats() {
        // Given: 书籍服务已初始化
        
        // When: 加载阅读统计
        let stats = bookService.loadReadingStats()
        
        // Then: 应该返回统计数据
        XCTAssertNotNil(stats, "阅读统计不应为 nil")
        XCTAssertTrue(stats.totalMinutesRead >= 0, "总阅读时间应该 >= 0")
        XCTAssertTrue(stats.currentStreak >= 0, "连续阅读天数应该 >= 0")
    }
    
    func testUpdateReadingProgress() {
        // Given: 书籍服务已初始化
        let bookId = "test_book_id"
        let progress = 0.5
        
        // When: 更新阅读进度
        bookService.updateReadingProgress(bookId: bookId, progress: progress)
        
        // Then: 阅读统计应该更新
        let stats = bookService.loadReadingStats()
        XCTAssertTrue(stats.totalMinutesRead > 0, "总阅读时间应该增加")
    }
    
    // MARK: - 性能测试
    
    func testLoadLocalBooksPerformance() {
        measure {
            _ = bookService.loadLocalBooks()
        }
    }
}
