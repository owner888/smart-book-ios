// ReaderView.swift - 书籍阅读器主视图（支持多语言）

import SwiftUI

struct ReaderView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    
    // ViewModel
    @State private var viewModel: ReaderViewModel
    
    // UI状态
    @State private var showSettings = false
    @State private var showTOC = false
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    
    init(book: Book) {
        self.book = book
        _viewModel = State(wrappedValue: ReaderViewModel(book: book))
    }
    
    private var pages: [String] { viewModel.allPages.map { $0.content } }
    
    private var currentChapterIndex: Int {
        guard viewModel.currentPageIndex < viewModel.allPages.count else { return 0 }
        return viewModel.allPages[viewModel.currentPageIndex].chapterIndex
    }
    
    private var currentChapterTitle: String {
        guard let content = viewModel.epubContent, currentChapterIndex < content.chapters.count else { return "" }
        return content.chapters[currentChapterIndex].title
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                viewModel.settings.bgColor.ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if let content = viewModel.epubContent, !content.chapters.isEmpty {
                    readerContent(geometry: geometry)
                } else {
                    errorView
                }
                
                if showControls && !viewModel.isLoading {
                    controlsOverlay
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .onAppear { 
            Task { await viewModel.loadBook() }
            startControlsTimer()
        }
        .onDisappear { 
            viewModel.saveProgress()
            controlsTimer?.invalidate()
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView(settings: $viewModel.settings)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTOC) {
            if let content = viewModel.epubContent {
                TOCView(chapters: content.chapters, currentIndex: currentChapterIndex) { index in
                    viewModel.goToChapter(index)
                    showTOC = false
                }
            }
        }
        .onChange(of: viewModel.settings.fontSize) { _, _ in 
            viewModel.repaginateAndSave()
        }
        .onChange(of: viewModel.settings.lineSpacing) { _, _ in 
            viewModel.repaginateAndSave()
        }
        .onChange(of: viewModel.settings.backgroundColor) { _, _ in 
            viewModel.settings.save()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5).tint(viewModel.settings.txtColor)
            Text(L("common.loading")).foregroundColor(viewModel.settings.txtColor.opacity(0.7))
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50)).foregroundColor(.orange)
            Text(L("error.loading")).foregroundColor(viewModel.settings.txtColor)
            Button(L("common.back")) { dismiss() }.buttonStyle(.bordered)
        }
    }
    
    @ViewBuilder
    private func readerContent(geometry: GeometryProxy) -> some View {
        let pageWidth = geometry.size.width
        let pageHeight = geometry.size.height
        
        ZStack {
            switch viewModel.settings.pageTurnStyle {
            case .curl:
                PageCurlView(
                    allPages: viewModel.allPages,
                    currentPageIndex: $viewModel.currentPageIndex,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    settings: viewModel.settings,
                    onPageChange: { viewModel.saveProgress() },
                    onTapCenter: { toggleControls() }
                )
                
            case .fade:
                if !pages.isEmpty && viewModel.currentPageIndex < pages.count {
                    PageContentView(
                        pageIndex: viewModel.currentPageIndex,
                        allPages: viewModel.allPages,
                        settings: viewModel.settings,
                        width: pageWidth,
                        height: pageHeight
                    )
                    .transition(.opacity)
                    .id(viewModel.currentPageIndex)
                    .animation(.easeInOut(duration: 0.4), value: viewModel.currentPageIndex)
                }
                tapAreaOverlay(pageWidth: pageWidth, pageHeight: pageHeight)
                
            case .slide:
                if !pages.isEmpty {
                    TabView(selection: $viewModel.currentPageIndex) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, _ in
                            PageContentView(
                                pageIndex: index,
                                allPages: viewModel.allPages,
                                settings: viewModel.settings,
                                width: pageWidth,
                                height: pageHeight
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentPageIndex)
                    .onChange(of: viewModel.currentPageIndex) { _, _ in 
                        viewModel.saveProgress()
                    }
                }
                centerTapArea(pageWidth: pageWidth, pageHeight: pageHeight)
            }
        }
        .gesture(viewModel.settings.pageTurnStyle == .fade ? swipeGesture : nil)
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                if abs(h) > abs(v) {
                    if h > 80 { viewModel.previousPage() }
                    else if h < -80 { viewModel.nextPage() }
                }
            }
    }
    
    @ViewBuilder
    private func tapAreaOverlay(pageWidth: CGFloat, pageHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: pageWidth * 0.25).contentShape(Rectangle())
                .onTapGesture { viewModel.previousPage() }
            Color.clear.frame(width: pageWidth * 0.5).contentShape(Rectangle())
                .onTapGesture { toggleControls() }
            Color.clear.frame(width: pageWidth * 0.25).contentShape(Rectangle())
                .onTapGesture { viewModel.nextPage() }
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
            Text(viewModel.epubContent?.metadata.title ?? book.title)
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
                    ProgressView(value: Double(viewModel.currentPageIndex + 1), total: Double(pages.count)).tint(.white)
                    HStack {
                        Text(currentChapterTitle).font(.caption).foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(String(format: L("reader.pageIndicator"), viewModel.currentPageIndex + 1, pages.count))
                            .font(.caption).foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 30) {
                Button { viewModel.previousChapter() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left.2").font(.title2)
                        Text(L("reader.previousPage")).font(.caption2)
                    }.foregroundColor(.white)
                }
                .disabled(currentChapterIndex == 0)
                .opacity(currentChapterIndex == 0 ? 0.5 : 1)
                
                Button { showSettings = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "textformat.size").font(.title2)
                        Text(L("settings.title")).font(.caption2)
                    }.foregroundColor(.white)
                }
                
                Button { viewModel.nextChapter() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.right.2").font(.title2)
                        Text(L("reader.nextChapter")).font(.caption2)
                    }.foregroundColor(.white)
                }
                .disabled(currentChapterIndex >= (viewModel.epubContent?.chapters.count ?? 1) - 1)
                .opacity(currentChapterIndex >= (viewModel.epubContent?.chapters.count ?? 1) - 1 ? 0.5 : 1)
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(LinearGradient(colors: [Color.clear, Color.black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }
    
    private func hideControls() {
        if showControls {
            withAnimation(.easeInOut(duration: 0.2)) { showControls = false }
        }
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

#Preview {
    ReaderView(book: Book(id: "preview", title: "Preview Book", author: "Author", coverURL: nil, filePath: nil, addedDate: nil))
}
