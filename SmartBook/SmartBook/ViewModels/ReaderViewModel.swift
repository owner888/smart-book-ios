// ReaderViewModel.swift - 阅读器视图模型

import Foundation
import SwiftUI

/// 阅读器视图模型
@MainActor
@Observable
class ReaderViewModel {
    // MARK: - 状态

    /// EPUB内容
    var epubContent: EPUBContent?

    /// 是否正在加载
    var isLoading = true

    /// 当前页码索引
    var currentPageIndex = 0

    /// 所有页面
    var allPages: [BookPage] = []

    /// 阅读器设置
    var settings = ReaderSettings.load()

    // MARK: - 依赖

    private let book: Book

    // MARK: - 初始化

    init(book: Book) {
        self.book = book
    }

    // MARK: - 业务逻辑

    /// 加载书籍内容
    func loadBook() async {
        isLoading = true

        guard let filePath = book.filePath else {
            isLoading = false
            return
        }

        // 解析 EPUB 内容
        let content = EPUBParser.parseContent(from: filePath)

        epubContent = content
        paginateEntireBook()

        // 加载阅读进度
        if let progress = ReadingProgress.load(for: book.id) {
            currentPageIndex = min(progress.pageIndex, allPages.count - 1)
        }

        isLoading = false
    }

    /// 分页整本书
    func paginateEntireBook() {
        guard let content = epubContent else {
            allPages = []
            return
        }

        var newPages: [BookPage] = []
        for (chapterIndex, chapter) in content.chapters.enumerated() {
            for pageContent in paginateText(chapter.content) {
                newPages.append(
                    BookPage(
                        content: pageContent,
                        chapterIndex: chapterIndex,
                        chapterTitle: chapter.title
                    )
                )
            }
        }
        allPages = newPages.isEmpty ? [BookPage(content: "", chapterIndex: 0, chapterTitle: "")] : newPages
    }

    /// 分页文本
    private func paginateText(_ text: String) -> [String] {
        let charsPerPage = Int(3000 / settings.fontSize * 18)
        guard !text.isEmpty else { return [""] }

        var pages: [String] = []
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: charsPerPage, limitedBy: text.endIndex) ?? text.endIndex
            var actualEndIndex = endIndex

            if actualEndIndex < text.endIndex {
                if let paragraphBreak = text[currentIndex..<endIndex].lastIndex(of: "\n") {
                    actualEndIndex = text.index(after: paragraphBreak)
                } else if let sentenceBreak = text[currentIndex..<endIndex].lastIndex(where: { "。！？.!?".contains($0) })
                {
                    actualEndIndex = text.index(after: sentenceBreak)
                }
            }

            let pageText = String(text[currentIndex..<actualEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !pageText.isEmpty { pages.append(pageText) }
            currentIndex = actualEndIndex
        }
        return pages.isEmpty ? [""] : pages
    }

    /// 重新分页并保存
    func repaginateAndSave() {
        let savedPage = currentPageIndex
        paginateEntireBook()
        currentPageIndex = min(savedPage, allPages.count - 1)
        settings.save()
    }

    /// 下一页
    func nextPage() {
        guard currentPageIndex < allPages.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPageIndex += 1
        }
        saveProgress()
    }

    /// 上一页
    func previousPage() {
        guard currentPageIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPageIndex -= 1
        }
        saveProgress()
    }

    /// 下一章
    func nextChapter() {
        guard let content = epubContent else { return }

        let currentChapterIndex = getCurrentChapterIndex()
        let nextChapterIndex = currentChapterIndex + 1

        if nextChapterIndex < content.chapters.count,
            let pageIndex = allPages.firstIndex(where: { $0.chapterIndex == nextChapterIndex })
        {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPageIndex = pageIndex
            }
            saveProgress()
        }
    }

    /// 上一章
    func previousChapter() {
        let currentChapterIndex = getCurrentChapterIndex()
        let prevChapterIndex = currentChapterIndex - 1

        if prevChapterIndex >= 0,
            let pageIndex = allPages.firstIndex(where: { $0.chapterIndex == prevChapterIndex })
        {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPageIndex = pageIndex
            }
            saveProgress()
        }
    }

    /// 跳转到指定章节
    func goToChapter(_ index: Int) {
        guard let content = epubContent,
            index >= 0 && index < content.chapters.count,
            let pageIndex = allPages.firstIndex(where: { $0.chapterIndex == index })
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            currentPageIndex = pageIndex
        }
        saveProgress()
    }

    /// 保存阅读进度
    func saveProgress() {
        let chapterIndex = getCurrentChapterIndex()
        ReadingProgress(
            bookId: book.id,
            chapterIndex: chapterIndex,
            pageIndex: currentPageIndex,
            scrollOffset: 0,
            lastReadDate: Date()
        ).save()
    }

    /// 获取当前章节索引
    private func getCurrentChapterIndex() -> Int {
        guard currentPageIndex < allPages.count else { return 0 }
        return allPages[currentPageIndex].chapterIndex
    }
}
