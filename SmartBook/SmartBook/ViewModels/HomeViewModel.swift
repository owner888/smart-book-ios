// HomeViewModel.swift - 首页视图模型

import Foundation
import SwiftUI

/// 首页视图模型
@MainActor
@Observable
class HomeViewModel {
    // MARK: - 状态
    
    /// 最近阅读的书籍
    var recentBooks: [Book] = []
    
    /// 收藏的书籍
    var favoriteBooks: [Book] = []
    
    /// 阅读统计数据
    var readingStats: ReadingStats = ReadingStats()
    
    /// 选中的书籍（用于阅读）
    var selectedBookForReading: Book?
    
    /// 是否显示签到提示
    var showingCheckInAlert = false
    
    /// 签到消息
    var checkInMessage = ""
    
    /// 是否正在加载
    var isLoading = false
    
    // MARK: - 依赖
    
    private let bookService: BookService
    private let checkInService: CheckInService
    
    // MARK: - 初始化
    
    init(bookService: BookService, checkInService: CheckInService) {
        self.bookService = bookService
        self.checkInService = checkInService
    }
    
    // MARK: - 业务逻辑
    
    /// 加载首页数据
    func loadData() async {
        isLoading = true
        
        // 并行加载数据
        async let recent = loadRecentBooks()
        async let favorites = loadFavoriteBooks()
        async let stats = loadReadingStats()
        
        recentBooks = await recent
        favoriteBooks = await favorites
        readingStats = await stats
        
        isLoading = false
    }
    
    /// 加载最近阅读的书籍
    private func loadRecentBooks() async -> [Book] {
        // 从 bookService 获取最近阅读的书籍
        return bookService.getRecentBooks()
    }
    
    /// 加载收藏的书籍
    private func loadFavoriteBooks() async -> [Book] {
        // 从 bookService 获取收藏的书籍
        return bookService.getFavoriteBooks()
    }
    
    /// 加载阅读统计
    private func loadReadingStats() async -> ReadingStats {
        return bookService.loadReadingStats()
    }
    
    /// 每日签到
    func checkIn() async {
        do {
            let result = try await checkInService.checkIn()
            checkInMessage = result.message
            showingCheckInAlert = true
            
            // 刷新统计数据
            readingStats = await loadReadingStats()
        } catch {
            checkInMessage = error.localizedDescription
            showingCheckInAlert = true
        }
    }
    
    /// 选择书籍进行阅读
    /// - Parameter book: 选中的书籍
    func selectBookForReading(_ book: Book) {
        selectedBookForReading = book
    }
    
    /// 刷新数据
    func refresh() async {
        await loadData()
    }
}
