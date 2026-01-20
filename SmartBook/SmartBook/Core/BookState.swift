// BookState.swift - 书籍状态管理
// 只负责书籍相关的状态，不持有服务

import SwiftUI

@MainActor
@Observable
class BookState {
    // 当前选中的书籍
    var selectedBook: Book?
    
    // 书籍列表
    var books: [Book] = []
    
    // 加载状态
    var isLoading = false
    
    // 错误信息
    var errorMessage: String?
    
    // 加载书籍（需要注入 bookService）
    func loadBooks(using bookService: BookService) async {
        isLoading = true
        errorMessage = nil
        do {
            books = try await bookService.fetchBooks()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // 选择书籍
    func selectBook(_ book: Book?) {
        selectedBook = book
    }
    
    // 清除错误
    func clearError() {
        errorMessage = nil
    }
}
