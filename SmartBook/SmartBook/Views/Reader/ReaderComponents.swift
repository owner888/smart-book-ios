// ReaderComponents.swift - 阅读器子组件集合

import SwiftUI

// MARK: - 加载视图
struct ReaderLoadingView: View {
    let txtColor: Color

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5).tint(txtColor)
            Text(L("common.loading")).foregroundColor(txtColor.opacity(0.7))
        }
    }
}

// MARK: - 错误视图
struct ReaderErrorView: View {
    let txtColor: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))  // 装饰性大图标.foregroundColor(.orange)
            Text(L("error.loading")).foregroundColor(txtColor)
            Button(L("common.back"), action: onDismiss).buttonStyle(.bordered)
        }
    }
}

// MARK: - 顶部工具栏
struct ReaderTopBar: View {
    let title: String
    let onBack: () -> Void
    let onShowTOC: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title2).foregroundColor(.white)
                    .padding(12).background(Color.black.opacity(0.5)).clipShape(Circle())
            }
            Spacer()
            Text(title)
                .font(.headline).foregroundColor(.white).lineLimit(1)
            Spacer()
            Button(action: onShowTOC) {
                Image(systemName: "list.bullet")
                    .font(.title2).foregroundColor(.white)
                    .padding(12).background(Color.black.opacity(0.5)).clipShape(Circle())
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - 进度信息
struct ReaderProgressInfo: View {
    let currentPage: Int
    let totalPages: Int
    let chapterTitle: String

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: Double(currentPage + 1), total: Double(totalPages))
                .tint(.white)
            HStack {
                Text(chapterTitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(String(format: L("reader.pageIndicator"), currentPage + 1, totalPages))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - 控制按钮
struct ReaderControlButtons: View {
    let canGoPrevChapter: Bool
    let canGoNextChapter: Bool
    let onPrevChapter: () -> Void
    let onShowSettings: () -> Void
    let onNextChapter: () -> Void

    var body: some View {
        HStack(spacing: 30) {
            Button(action: onPrevChapter) {
                VStack(spacing: 4) {
                    Image(systemName: "chevron.left.2").font(.title2)
                    Text(L("reader.previousPage")).font(.caption2)
                }.foregroundColor(.white)
            }
            .disabled(!canGoPrevChapter)
            .opacity(canGoPrevChapter ? 1 : 0.5)

            Button(action: onShowSettings) {
                VStack(spacing: 4) {
                    Image(systemName: "textformat.size").font(.title2)
                    Text(L("settings.title")).font(.caption2)
                }.foregroundColor(.white)
            }

            Button(action: onNextChapter) {
                VStack(spacing: 4) {
                    Image(systemName: "chevron.right.2").font(.title2)
                    Text(L("reader.nextChapter")).font(.caption2)
                }.foregroundColor(.white)
            }
            .disabled(!canGoNextChapter)
            .opacity(canGoNextChapter ? 1 : 0.5)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 底部工具栏
struct ReaderBottomBar: View {
    let currentPage: Int
    let totalPages: Int
    let chapterTitle: String
    let currentChapterIndex: Int
    let totalChapters: Int
    let onPrevChapter: () -> Void
    let onShowSettings: () -> Void
    let onNextChapter: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if totalPages > 0 {
                ReaderProgressInfo(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    chapterTitle: chapterTitle
                )
            }

            ReaderControlButtons(
                canGoPrevChapter: currentChapterIndex > 0,
                canGoNextChapter: currentChapterIndex < totalChapters - 1,
                onPrevChapter: onPrevChapter,
                onShowSettings: onShowSettings,
                onNextChapter: onNextChapter
            )
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - 点击区域（淡入淡出模式）
struct ReaderTapAreaOverlay: View {
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let showControls: Bool
    let onPrevPage: () -> Void
    let onToggleControls: () -> Void
    let onNextPage: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: pageWidth * 0.25)
                .contentShape(Rectangle())
                .onTapGesture(perform: onPrevPage)

            Color.clear
                .frame(width: pageWidth * 0.5)
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleControls)

            Color.clear
                .frame(width: pageWidth * 0.25)
                .contentShape(Rectangle())
                .onTapGesture(perform: onNextPage)
        }
        .frame(height: pageHeight)
        .allowsHitTesting(!showControls)
    }
}

// MARK: - 中心点击区域（滑动模式）
struct ReaderCenterTapArea: View {
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let showControls: Bool
    let onTap: () -> Void

    var body: some View {
        Color.clear
            .frame(width: pageWidth, height: pageHeight)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .allowsHitTesting(!showControls)
    }
}
