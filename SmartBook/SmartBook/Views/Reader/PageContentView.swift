// PageContentView.swift - 共享的页面内容视图
// 用于所有翻页模式（滑动、卷页、淡入）

import SwiftUI

struct PageContentView: View {
    let page: BookPage
    let pageIndex: Int
    let totalPages: Int
    let allPages: [BookPage]
    let settings: ReaderSettings
    let width: CGFloat
    let height: CGFloat

    // 计算当前章节剩余页数
    private var pagesUntilNextChapter: Int {
        let chapterLastPageIndex = allPages.lastIndex(where: { $0.chapterIndex == page.chapterIndex }) ?? pageIndex
        return max(0, chapterLastPageIndex - pageIndex)
    }

    // 剩余页数文本
    private var remainingPagesText: String {
        if pagesUntilNextChapter == 0 {
            return L("reader.nextChapter.now")
        } else {
            return String(format: L("reader.nextChapter.inPages"), pagesUntilNextChapter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部信息栏
            HStack {
                Text(remainingPagesText)
                    .font(.caption)
                    .foregroundColor(settings.txtColor.opacity(0.5))

                Spacer()

                Text(page.chapterTitle)
                    .font(.caption)
                    .foregroundColor(settings.txtColor.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // 正文内容
            Text(page.content)
                .font(settings.font)
                .foregroundColor(settings.txtColor)
                .lineSpacing(settings.lineSpacing)
                .multilineTextAlignment(settings.textAlignment)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)

            // 底部页码
            Text("\(pageIndex + 1) / \(totalPages)")
                .font(.caption)
                .foregroundColor(settings.txtColor.opacity(0.5))
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .frame(width: width, height: height)
        .background(settings.bgColor)
        .clipped()
    }
}

// MARK: - 便捷初始化（从数组索引）
extension PageContentView {
    init(pageIndex: Int, allPages: [BookPage], settings: ReaderSettings, width: CGFloat, height: CGFloat) {
        self.pageIndex = pageIndex
        self.allPages = allPages
        self.page =
            pageIndex < allPages.count ? allPages[pageIndex] : BookPage(content: "", chapterIndex: 0, chapterTitle: "")
        self.totalPages = allPages.count
        self.settings = settings
        self.width = width
        self.height = height
    }
}
