// SearchViewModel.swift - 搜索视图模型

import Foundation
import SwiftUI

/// 搜索视图模型
@MainActor
@Observable
class SearchViewModel {
    // MARK: - 状态
    
    /// 搜索文本
    var searchText = ""
    
    /// 搜索结果
    var searchResults: [SearchResult] = []
    
    /// 是否正在搜索
    var isSearching = false
    
    /// 错误信息
    var errorMessage: String?
    
    /// 是否显示错误
    var showingError = false
    
    /// 选中的书籍
    var selectedBook: Book?
    
    /// 最近搜索历史
    var recentSearches: [String] = []
    
    /// 选中要阅读的书籍
    var selectedBookForReading: Book?
    
    // MARK: - 依赖
    
    private let bookService: BookService
    
    // MARK: - 初始化
    
    init(bookService: BookService) {
        self.bookService = bookService
    }
    
    // MARK: - 业务逻辑
    
    /// 执行搜索
    func search() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        guard searchText.count >= 2 else {
            return // 至少2个字符才搜索
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            // 在所有书籍中搜索
            let results = try await searchInAllBooks(query: searchText)
            searchResults = results
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isSearching = false
    }
    
    /// 在所有书籍中搜索
    /// - Parameter query: 搜索关键词
    /// - Returns: 搜索结果列表
    private func searchInAllBooks(query: String) async throws -> [SearchResult] {
        var results: [SearchResult] = []
        
        // TODO: 实现实际的搜索逻辑
        // 这里需要调用 bookService 的搜索方法
        // 示例实现：
        // for book in books {
        //     let bookResults = try await bookService.searchBook(book.id, query: query)
        //     results.append(contentsOf: bookResults)
        // }
        
        return results
    }
    
    /// 清空搜索
    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
    }
    
    /// 选择搜索结果
    /// - Parameter result: 搜索结果
    /// - Parameter book: 对应的书籍
    func selectResult(_ result: SearchResult, book: Book) {
        selectedBook = book
    }
    
    /// 加载最近搜索历史
    func loadRecentSearches() async {
        recentSearches = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
    }
    
    /// 添加到最近搜索
    /// - Parameter text: 搜索文本
    func addToRecentSearches(_ text: String) {
        guard !text.isEmpty else { return }
        var searches = recentSearches
        searches.removeAll { $0 == text }
        searches.insert(text, at: 0)
        if searches.count > 5 {
            searches = Array(searches.prefix(5))
        }
        recentSearches = searches
        UserDefaults.standard.set(searches, forKey: "RecentSearches")
    }
    
    /// 清空最近搜索
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "RecentSearches")
    }
    
    /// 选择书籍进行阅读
    /// - Parameter book: 选中的书籍
    func selectBookForReading(_ book: Book) {
        selectedBookForReading = book
    }
}
