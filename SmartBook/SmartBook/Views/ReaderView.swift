// ReaderView.swift - 书籍阅读器主视图（组件化重构版）

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
                    ReaderLoadingView(txtColor: viewModel.settings.txtColor)
                } else if let content = viewModel.epubContent, !content.chapters.isEmpty {
                    readerContent(geometry: geometry)
                } else {
                    ReaderErrorView(txtColor: viewModel.settings.txtColor) {
                        dismiss()
                    }
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
                
                ReaderTapAreaOverlay(
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    showControls: showControls,
                    onPrevPage: { viewModel.previousPage() },
                    onToggleControls: { toggleControls() },
                    onNextPage: { viewModel.nextPage() }
                )
                
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
                
                ReaderCenterTapArea(
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    showControls: showControls,
                    onTap: { toggleControls() }
                )
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
    
    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            ReaderTopBar(
                title: viewModel.epubContent?.metadata.title ?? book.title,
                onBack: { dismiss() },
                onShowTOC: { showTOC = true }
            )
            
            Spacer()
            
            ReaderBottomBar(
                currentPage: viewModel.currentPageIndex,
                totalPages: pages.count,
                chapterTitle: currentChapterTitle,
                currentChapterIndex: currentChapterIndex,
                totalChapters: viewModel.epubContent?.chapters.count ?? 1,
                onPrevChapter: { viewModel.previousChapter() },
                onShowSettings: { showSettings = true },
                onNextChapter: { viewModel.nextChapter() }
            )
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
    ReaderView(book: Book(
        id: "preview",
        title: "Preview Book",
        author: "Author",
        coverURL: nil,
        filePath: nil,
        addedDate: nil
    ))
}
