// ReaderViewModel.swift - 阅读器视图模型

import Foundation
import SwiftUI

/// 阅读器主题
enum ReaderTheme: String, CaseIterable {
    case light = "浅色"
    case dark = "深色"
    case sepia = "护眼"
}

/// 阅读器视图模型
@MainActor
@Observable
class ReaderViewModel {
    // MARK: - 状态
    
    /// 当前页码
    var currentPage = 0
    
    /// 总页数
    var totalPages = 0
    
    /// 字体大小
    var fontSize: CGFloat = 18
    
    /// 阅读主题
    var theme: ReaderTheme = .light
    
    /// 是否全屏
    var isFullScreen = false
    
    /// 是否显示菜单
    var showingMenu = false
    
    /// 章节列表
    var chapters: [EPUBChapter] = []
    
    /// 当前章节
    var currentChapter: EPUBChapter?
    
    /// 当前章节索引
    var currentChapterIndex = 0
    
    /// 是否正在加载
    var isLoading = false
    
    /// 错误信息
    var errorMessage: String?
    
    /// 阅读进度（0.0-1.0）
    var readingProgress: Double = 0.0
    
    // MARK: - 依赖
    
    private let book: Book
    private let bookService: BookService
    
    // MARK: - 初始化
    
    init(book: Book, bookService: BookService) {
        self.book = book
        self.bookService = bookService
    }
    
    // MARK: - 业务逻辑
    
    /// 加载书籍内容
    func loadBook() async {
        guard let filePath = book.filePath else {
            errorMessage = "书籍文件路径不存在"
            return
        }
        
        isLoading = true
        
        // 解析EPUB内容
        if let content = EPUBParser.parseContent(from: filePath) {
            chapters = content.chapters
            if !chapters.isEmpty {
                currentChapter = chapters[0]
                currentChapterIndex = 0
                totalPages = calculateTotalPages()
            }
        }
        
        // 加载上次阅读进度
        loadReadingProgress()
        
        isLoading = false
    }
    
    /// 下一页
    func nextPage() {
        guard currentPage < totalPages - 1 else {
            // 已经是最后一页
            return
        }
        currentPage += 1
        updateReadingProgress()
    }
    
    /// 上一页
    func previousPage() {
        guard currentPage > 0 else {
            // 已经是第一页
            return
        }
        currentPage -= 1
        updateReadingProgress()
    }
    
    /// 跳转到指定章节
    /// - Parameter index: 章节索引
    func goToChapter(_ index: Int) {
        guard index >= 0 && index < chapters.count else { return }
        currentChapterIndex = index
        currentChapter = chapters[index]
        // 重新计算页码
        currentPage = calculatePageForChapter(index)
        updateReadingProgress()
    }
    
    /// 增大字体
    func increaseFontSize() {
        fontSize = min(fontSize + 2, 32)
        // 字体变化后重新计算页数
        totalPages = calculateTotalPages()
    }
    
    /// 减小字体
    func decreaseFontSize() {
        fontSize = max(fontSize - 2, 12)
        // 字体变化后重新计算页数
        totalPages = calculateTotalPages()
    }
    
    /// 切换主题
    /// - Parameter newTheme: 新主题
    func changeTheme(_ newTheme: ReaderTheme) {
        theme = newTheme
    }
    
    /// 切换全屏
    func toggleFullScreen() {
        isFullScreen.toggle()
    }
    
    /// 切换菜单显示
    func toggleMenu() {
        showingMenu.toggle()
    }
    
    /// 保存阅读进度
    func saveReadingProgress() {
        readingProgress = Double(currentPage) / Double(max(totalPages, 1))
        bookService.updateReadingProgress(bookId: book.id, progress: readingProgress)
    }
    
    /// 加载阅读进度
    private func loadReadingProgress() {
        // TODO: 从 bookService 加载上次的阅读进度
        // let progress = bookService.getReadingProgress(bookId: book.id)
        // currentPage = Int(progress * Double(totalPages))
    }
    
    /// 更新阅读进度
    private func updateReadingProgress() {
        readingProgress = Double(currentPage) / Double(max(totalPages, 1))
        
        // 定期保存进度（避免频繁保存）
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒后保存
            saveReadingProgress()
        }
    }
    
    /// 计算总页数
    private func calculateTotalPages() -> Int {
        // TODO: 根据屏幕尺寸和字体大小计算总页数
        // 这是一个简化的实现
        return chapters.count * 10 // 假设每章10页
    }
    
    /// 计算章节对应的页码
    private func calculatePageForChapter(_ index: Int) -> Int {
        // TODO: 实现实际的页码计算
        return index * 10
    }
}
