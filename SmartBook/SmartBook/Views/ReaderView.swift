// ReaderView.swift - 书籍阅读器主视图

import SwiftUI

struct ReaderView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @State private var epubContent: EPUBContent?
    @State private var isLoading = true
    @State private var currentPageIndex = 0
    @State private var allPages: [BookPage] = []
    @State private var showSettings = false
    @State private var showTOC = false
    @State private var showControls = true
    @State private var settings = ReaderSettings.load()
    @State private var controlsTimer: Timer?
    
    // MARK: - 计算属性
    private var pages: [String] { allPages.map { $0.content } }
    
    private var currentChapterIndex: Int {
        guard currentPageIndex < allPages.count else { return 0 }
        return allPages[currentPageIndex].chapterIndex
    }
    
    private var currentChapterTitle: String {
        guard let content = epubContent, currentChapterIndex < content.chapters.count else { return "" }
        return content.chapters[currentChapterIndex].title
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                settings.bgColor.ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let content = epubContent, !content.chapters.isEmpty {
                    readerContent(geometry: geometry)
                } else {
                    errorView
                }
                
                if showControls && !isLoading {
                    controlsOverlay
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .onAppear { loadBook(); startControlsTimer() }
        .onDisappear { saveProgress(); controlsTimer?.invalidate() }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView(settings: $settings)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTOC) {
            if let content = epubContent {
                TOCView(chapters: content.chapters, currentIndex: currentChapterIndex) { index in
                    goToChapter(index)
                    showTOC = false
                }
            }
        }
        .onChange(of: settings.fontSize) { _, _ in repaginateAndSave() }
        .onChange(of: settings.lineSpacing) { _, _ in repaginateAndSave() }
        .onChange(of: settings.backgroundColor) { _, _ in settings.save() }
    }
    
    // MARK: - 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5).tint(settings.txtColor)
            Text("正在加载书籍...").foregroundColor(settings.txtColor.opacity(0.7))
        }
    }
    
    // MARK: - 错误视图
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50)).foregroundColor(.orange)
            Text("无法加载书籍内容").foregroundColor(settings.txtColor)
            Button("返回") { dismiss() }.buttonStyle(.bordered)
        }
    }
    
    // MARK: - 阅读内容
    @ViewBuilder
    private func readerContent(geometry: GeometryProxy) -> some View {
        let pageWidth = geometry.size.width
        let pageHeight = geometry.size.height
        
        ZStack {
            switch settings.pageTurnStyle {
            case .curl:
                PageCurlView(
                    allPages: allPages,
                    currentPageIndex: $currentPageIndex,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    settings: settings,
                    onPageChange: { saveProgress() },
                    onTapCenter: { toggleControls() }
                )
                
            case .fade:
                if !pages.isEmpty && currentPageIndex < pages.count {
                    PageContentView(pageIndex: currentPageIndex, allPages: allPages, settings: settings, width: pageWidth, height: pageHeight)
                        .transition(.opacity)
                        .id(currentPageIndex)
                        .animation(.easeInOut(duration: 0.4), value: currentPageIndex)
                }
                tapAreaOverlay(pageWidth: pageWidth, pageHeight: pageHeight)
                
            case .slide:
                if !pages.isEmpty {
                    TabView(selection: $currentPageIndex) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, _ in
                            PageContentView(pageIndex: index, allPages: allPages, settings: settings, width: pageWidth, height: pageHeight)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentPageIndex)
                    .onChange(of: currentPageIndex) { _, _ in saveProgress() }
                }
                centerTapArea(pageWidth: pageWidth, pageHeight: pageHeight)
            }
        }
        .gesture(settings.pageTurnStyle == .fade ? swipeGesture : nil)
    }
    
    // MARK: - 手势
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                if abs(h) > abs(v) {
                    if h > 80 { previousPage() }
                    else if h < -80 { nextPage() }
                }
            }
    }
    
    // MARK: - 点击区域
    @ViewBuilder
    private func tapAreaOverlay(pageWidth: CGFloat, pageHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: pageWidth * 0.25).contentShape(Rectangle())
                .onTapGesture { previousPage() }
            Color.clear.frame(width: pageWidth * 0.5).contentShape(Rectangle())
                .onTapGesture { toggleControls() }
            Color.clear.frame(width: pageWidth * 0.25).contentShape(Rectangle())
                .onTapGesture { nextPage() }
        }
        .frame(height: pageHeight)
        .allowsHitTesting(!showControls)
    }
    
    private func centerTapArea(pageWidth: CGFloat, pageHeight: CGFloat) -> some View {
        Color.clear
            .frame(width: pageWidth, height: pageHeight)
            .contentShape(Rectangle())
            .onTapGesture { toggleControls() }
            .allowsHitTesting(!showControls)
    }
    
    // MARK: - 控制层
    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomBar
        }
    }
    
    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title2).foregroundColor(.white)
                    .padding(12).background(Color.black.opacity(0.5)).clipShape(Circle())
            }
            Spacer()
            Text(epubContent?.metadata.title ?? book.title)
                .font(.headline).foregroundColor(.white).lineLimit(1)
            Spacer()
            Button { showTOC = true } label: {
                Image(systemName: "list.bullet")
                    .font(.title2).foregroundColor(.white)
                    .padding(12).background(Color.black.opacity(0.5)).clipShape(Circle())
            }
        }
        .padding()
        .background(LinearGradient(colors: [Color.black.opacity(0.7), Color.clear], startPoint: .top, endPoint: .bottom))
    }
    
    private var bottomBar: some View {
        VStack(spacing: 12) {
            if !pages.isEmpty {
                VStack(spacing: 4) {
                    ProgressView(value: Double(currentPageIndex + 1), total: Double(pages.count)).tint(.white)
                    HStack {
                        Text(currentChapterTitle).font(.caption).foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("\(currentPageIndex + 1) / \(pages.count)").font(.caption).foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 30) {
                Button { previousChapter() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left.2").font(.title2)
                        Text("上一章").font(.caption2)
                    }.foregroundColor(.white)
                }
                .disabled(currentChapterIndex == 0)
                .opacity(currentChapterIndex == 0 ? 0.5 : 1)
                
                Button { showSettings = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "textformat.size").font(.title2)
                        Text("设置").font(.caption2)
                    }.foregroundColor(.white)
                }
                
                Button { nextChapter() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.right.2").font(.title2)
                        Text("下一章").font(.caption2)
                    }.foregroundColor(.white)
                }
                .disabled(currentChapterIndex >= (epubContent?.chapters.count ?? 1) - 1)
                .opacity(currentChapterIndex >= (epubContent?.chapters.count ?? 1) - 1 ? 0.5 : 1)
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(LinearGradient(colors: [Color.clear, Color.black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }
    
    // MARK: - 方法
    private func loadBook() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            guard let filePath = book.filePath else {
                DispatchQueue.main.async { isLoading = false }
                return
            }
            let content = EPUBParser.parseContent(from: filePath)
            DispatchQueue.main.async {
                epubContent = content
                paginateEntireBook()
                if let progress = ReadingProgress.load(for: book.id) {
                    currentPageIndex = min(progress.pageIndex, allPages.count - 1)
                }
                isLoading = false
            }
        }
    }
    
    private func paginateEntireBook() {
        guard let content = epubContent else { allPages = []; return }
        var newPages: [BookPage] = []
        for (chapterIndex, chapter) in content.chapters.enumerated() {
            for pageContent in paginateText(chapter.content) {
                newPages.append(BookPage(content: pageContent, chapterIndex: chapterIndex, chapterTitle: chapter.title))
            }
        }
        allPages = newPages.isEmpty ? [BookPage(content: "", chapterIndex: 0, chapterTitle: "")] : newPages
    }
    
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
                } else if let sentenceBreak = text[currentIndex..<endIndex].lastIndex(where: { "。！？.!?".contains($0) }) {
                    actualEndIndex = text.index(after: sentenceBreak)
                }
            }
            
            let pageText = String(text[currentIndex..<actualEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !pageText.isEmpty { pages.append(pageText) }
            currentIndex = actualEndIndex
        }
        return pages.isEmpty ? [""] : pages
    }
    
    private func repaginateAndSave() {
        let savedPage = currentPageIndex
        paginateEntireBook()
        currentPageIndex = min(savedPage, allPages.count - 1)
        settings.save()
    }
    
    private func nextPage() {
        guard currentPageIndex < allPages.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex += 1 }
        saveProgress()
    }
    
    private func previousPage() {
        guard currentPageIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex -= 1 }
        saveProgress()
    }
    
    private func nextChapter() {
        guard let content = epubContent else { return }
        let nextChapterIndex = currentChapterIndex + 1
        if nextChapterIndex < content.chapters.count,
           let pageIndex = allPages.firstIndex(where: { $0.chapterIndex == nextChapterIndex }) {
            withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex = pageIndex }
            saveProgress()
        }
    }
    
    private func previousChapter() {
        let prevChapterIndex = currentChapterIndex - 1
        if prevChapterIndex >= 0,
           let pageIndex = allPages.firstIndex(where: { $0.chapterIndex == prevChapterIndex }) {
            withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex = pageIndex }
            saveProgress()
        }
    }
    
    private func goToChapter(_ index: Int) {
        guard let content = epubContent, index >= 0 && index < content.chapters.count,
              let pageIndex = allPages.firstIndex(where: { $0.chapterIndex == index }) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex = pageIndex }
        saveProgress()
    }
    
    private func saveProgress() {
        ReadingProgress(bookId: book.id, chapterIndex: currentChapterIndex, pageIndex: currentPageIndex, scrollOffset: 0, lastReadDate: Date()).save()
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
        if showControls { startControlsTimer() }
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) { showControls = false }
        }
    }
}

// MARK: - 预览
#Preview {
    ReaderView(book: Book(id: "preview", title: "预览书籍", author: "作者", coverURL: nil, filePath: nil, addedDate: nil))
}
