// BookshelfViewModel.swift - 书架视图模型

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 书架视图模型
@MainActor
@Observable
class BookshelfViewModel {
    // MARK: - 状态

    /// 是否显示文件导入器
    var showingImporter = false

    /// 是否显示删除确认对话框
    var showingDeleteAlert = false

    /// 待删除的书籍
    var bookToDelete: Book?

    /// 导入错误信息
    var importError: String?

    /// 是否显示错误提示
    var showingError = false

    /// 选中的书籍（用于阅读）
    var selectedBookForReading: Book?

    /// 是否正在加载
    var isLoading = false

    // MARK: - 依赖

    private let bookService: BookService
    private let bookState: BookState

    // MARK: - 初始化

    init(bookService: BookService, bookState: BookState) {
        self.bookService = bookService
        self.bookState = bookState
    }

    // MARK: - 业务逻辑

    /// 加载书籍列表
    func loadBooks() async {
        await bookState.loadBooks(using: bookService)
    }

    /// 处理文件导入
    /// - Parameter result: 文件选择结果
    func handleImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            var importedCount = 0
            for url in urls {
                do {
                    _ = try bookService.importBook(from: url)
                    importedCount += 1
                } catch {
                    importError = L("library.import.failed") + ": \(error.localizedDescription)"
                    showingError = true
                }
            }

            if importedCount > 0 {
                await loadBooks()
            }

        case .failure(let error):
            importError = L("error.fileNotFound") + ": \(error.localizedDescription)"
            showingError = true
        }
    }

    /// 删除书籍
    /// - Parameter book: 要删除的书籍
    func deleteBook(_ book: Book) {
        do {
            try bookService.deleteBook(book)
            bookState.books.removeAll { $0.id == book.id }
        } catch {
            importError = L("common.error") + ": \(error.localizedDescription)"
            showingError = true
        }
    }

    /// 显示导入器
    func showImporter() {
        showingImporter = true
    }

    /// 请求删除书籍
    /// - Parameter book: 要删除的书籍
    func requestDelete(_ book: Book) {
        bookToDelete = book
        showingDeleteAlert = true
    }

    /// 选择书籍进行阅读
    /// - Parameter book: 选中的书籍
    func selectBookForReading(_ book: Book) {
        if book.filePath != nil {
            selectedBookForReading = book
        } else {
            // 选择远程书籍，需要通知后端
            Task {
                do {
                    try await bookService.selectBook(book) { progress in
                        // 可以在这里处理进度，如果需要的话
                        Logger.debug("上传进度: \(Int(progress * 100))%")
                    }
                    bookState.selectedBook = book
                } catch {
                    importError = "选择书籍失败: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    /// 检查是否为用户导入的书籍
    /// - Parameter book: 书籍
    /// - Returns: 是否为用户导入
    func isUserImportedBook(_ book: Book) -> Bool {
        return bookService.isUserImportedBook(book)
    }
}
