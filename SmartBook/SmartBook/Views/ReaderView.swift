// ReaderView.swift - 书籍阅读器视图
// 支持滑动翻页、点击翻页、字体设置等功能

import SwiftUI

// MARK: - 翻页动画类型
enum PageTurnStyle: Int, Codable, CaseIterable {
    case slide = 0      // 滑动
    case curl = 1       // 卷页（3D翻页效果）
    case fade = 2       // 淡入淡出
    
    var name: String {
        switch self {
        case .slide: return "滑动"
        case .curl: return "翻页"
        case .fade: return "淡入"
        }
    }
}

// MARK: - 阅读器设置模型
struct ReaderSettings: Codable {
    var fontSize: CGFloat = 18
    var fontFamily: String = "System"
    var lineSpacing: CGFloat = 8
    var backgroundColor: String = "dark" // dark, sepia, light
    var brightness: Double = 1.0
    var textAlignment: TextAlignment = .leading
    var pageTurnStyle: PageTurnStyle = .curl // 默认使用卷页效果
    
    enum CodingKeys: String, CodingKey {
        case fontSize, fontFamily, lineSpacing, backgroundColor, brightness, textAlignment, pageTurnStyle
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 18
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily) ?? "System"
        lineSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .lineSpacing) ?? 8
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor) ?? "dark"
        brightness = try container.decodeIfPresent(Double.self, forKey: .brightness) ?? 1.0
        // TextAlignment 不直接支持 Codable，使用 Int 存储
        let alignmentRaw = try container.decodeIfPresent(Int.self, forKey: .textAlignment) ?? 0
        textAlignment = TextAlignment(rawValue: alignmentRaw) ?? .leading
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(fontFamily, forKey: .fontFamily)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(textAlignment.rawValue, forKey: .textAlignment)
    }
    
    // 保存设置
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "ReaderSettings")
        }
    }
    
    // 加载设置
    static func load() -> ReaderSettings {
        guard let data = UserDefaults.standard.data(forKey: "ReaderSettings"),
              let settings = try? JSONDecoder().decode(ReaderSettings.self, from: data) else {
            return ReaderSettings()
        }
        return settings
    }
}

// TextAlignment 扩展支持 rawValue（用于 Codable 存储）
extension TextAlignment {
    var rawValue: Int {
        switch self {
        case .leading: return 0
        case .center: return 1
        case .trailing: return 2
        }
    }
    
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .leading
        case 1: self = .center
        case 2: self = .trailing
        default: return nil
        }
    }
}

// MARK: - 阅读进度模型
struct ReadingProgress: Codable {
    var bookId: String
    var chapterIndex: Int
    var pageIndex: Int
    var scrollOffset: CGFloat
    var lastReadDate: Date
    
    static func load(for bookId: String) -> ReadingProgress? {
        let key = "ReadingProgress_\(bookId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let progress = try? JSONDecoder().decode(ReadingProgress.self, from: data) else {
            return nil
        }
        return progress
    }
    
    func save() {
        let key = "ReadingProgress_\(bookId)"
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - 主阅读器视图
struct ReaderView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @State private var epubContent: EPUBContent?
    @State private var isLoading = true
    @State private var currentChapterIndex = 0
    @State private var currentPageIndex = 0
    @State private var pages: [String] = []
    @State private var showSettings = false
    @State private var showTOC = false
    @State private var showControls = true
    @State private var settings = ReaderSettings.load()
    @State private var dragOffset: CGFloat = 0
    @State private var controlsTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                backgroundColor
                    .ignoresSafeArea()
                
                if isLoading {
                    // 加载中
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(textColor)
                        Text("正在加载书籍...")
                            .foregroundColor(textColor.opacity(0.7))
                    }
                } else if let content = epubContent, !content.chapters.isEmpty {
                    // 阅读内容
                    readerContent(geometry: geometry)
                } else {
                    // 错误状态
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("无法加载书籍内容")
                            .foregroundColor(textColor)
                        Button("返回") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // 控制层
                if showControls && !isLoading {
                    controlsOverlay
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .onAppear {
            loadBook()
            startControlsTimer()
        }
        .onDisappear {
            saveProgress()
            controlsTimer?.invalidate()
        }
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
        .onChange(of: settings.fontSize) { _, _ in
            paginateCurrentChapter()
            settings.save()
        }
        .onChange(of: settings.lineSpacing) { _, _ in
            paginateCurrentChapter()
            settings.save()
        }
        .onChange(of: settings.backgroundColor) { _, _ in
            settings.save()
        }
    }
    
    // MARK: - 阅读内容视图
    @ViewBuilder
    private func readerContent(geometry: GeometryProxy) -> some View {
        let pageWidth = geometry.size.width
        // 完全全屏高度
        let pageHeight = geometry.size.height
        
        ZStack {
            // 根据翻页样式选择不同的视图
            switch settings.pageTurnStyle {
            case .curl:
                // 卷页翻页效果
                PageCurlView(
                    pages: pages,
                    currentPageIndex: $currentPageIndex,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    backgroundColor: backgroundColor,
                    pageContent: { index in
                        pageView(text: pages[index], width: pageWidth, height: pageHeight)
                    },
                    onPageChange: { saveProgress() },
                    onTapCenter: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                        if showControls {
                            startControlsTimer()
                        }
                    }
                )
                
            case .fade:
                // 淡入淡出效果
                if !pages.isEmpty && currentPageIndex < pages.count {
                    pageView(text: pages[currentPageIndex], width: pageWidth, height: pageHeight)
                        .transition(.opacity)
                        .id(currentPageIndex)
                        .animation(.easeInOut(duration: 0.4), value: currentPageIndex)
                }
                // 淡入模式的触摸区域
                tapAreaOverlay(pageWidth: pageWidth, pageHeight: pageHeight)
                
            case .slide:
                // 滑动翻页效果
                if !pages.isEmpty {
                    TabView(selection: $currentPageIndex) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, pageText in
                            pageView(text: pageText, width: pageWidth, height: pageHeight)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentPageIndex)
                    .onChange(of: currentPageIndex) { oldValue, newValue in
                        saveProgress()
                    }
                }
                // 滑动模式的中间点击区域
                Color.clear
                    .frame(width: pageWidth, height: pageHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                        if showControls {
                            startControlsTimer()
                        }
                    }
                    .allowsHitTesting(!showControls)
            }
        }
        // 仅在淡入模式下添加滑动手势
        .gesture(
            settings.pageTurnStyle == .fade ?
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    // 仅处理水平滑动
                    if abs(horizontalAmount) > abs(verticalAmount) {
                        if horizontalAmount > 80 {
                            // 右滑 - 上一页
                            previousPage()
                        } else if horizontalAmount < -80 {
                            // 左滑 - 下一页
                            nextPage()
                        }
                    }
                }
            : nil
        )
    }
    
    // 点击区域覆盖层（淡入模式使用）
    @ViewBuilder
    private func tapAreaOverlay(pageWidth: CGFloat, pageHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            // 左侧点击区域（上一页）
            Color.clear
                .frame(width: pageWidth * 0.25)
                .contentShape(Rectangle())
                .onTapGesture {
                    previousPage()
                }
            
            // 中间点击区域（显示/隐藏控制）
            Color.clear
                .frame(width: pageWidth * 0.5)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls.toggle()
                    }
                    if showControls {
                        startControlsTimer()
                    }
                }
            
            // 右侧点击区域（下一页）
            Color.clear
                .frame(width: pageWidth * 0.25)
                .contentShape(Rectangle())
                .onTapGesture {
                    nextPage()
                }
        }
        .frame(height: pageHeight)
        .allowsHitTesting(!showControls)
    }
    
    // MARK: - 页面视图（iOS Books 风格，顶部章节信息，底部页数）
    private func pageView(text: String, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 顶部信息栏
            HStack {
                // 章节剩余页数
                Text("\(pagesLeftInChapter) 页后翻页")
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.5))
                
                Spacer()
                
                // 章节标题
                Text(currentChapterTitle)
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // 正文内容
            Text(text)
                .font(currentFont)
                .foregroundColor(textColor)
                .lineSpacing(settings.lineSpacing)
                .multilineTextAlignment(settings.textAlignment)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
            
            // 底部页码
            Text("\(currentPageIndex + 1) / \(pages.count)")
                .font(.caption)
                .foregroundColor(textColor.opacity(0.5))
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .frame(width: width, height: height)
        .background(backgroundColor)
        .clipped()
    }
    
    // 章节剩余页数
    private var pagesLeftInChapter: Int {
        max(0, pages.count - currentPageIndex - 1)
    }
    
    // MARK: - 控制层覆盖
    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(epubContent?.metadata.title ?? book.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Button {
                    showTOC = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
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
            
            Spacer()
            
            // 底部工具栏
            VStack(spacing: 12) {
                // 进度条
                if !pages.isEmpty {
                    VStack(spacing: 4) {
                        ProgressView(value: Double(currentPageIndex + 1), total: Double(pages.count))
                            .tint(.white)
                        
                        HStack {
                            Text(currentChapterTitle)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("\(currentPageIndex + 1) / \(pages.count)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 工具按钮
                HStack(spacing: 30) {
                    // 上一章
                    Button {
                        previousChapter()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "chevron.left.2")
                                .font(.title2)
                            Text("上一章")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .disabled(currentChapterIndex == 0)
                    .opacity(currentChapterIndex == 0 ? 0.5 : 1)
                    
                    // 字体设置
                    Button {
                        showSettings = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "textformat.size")
                                .font(.title2)
                            Text("设置")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    
                    // 下一章
                    Button {
                        nextChapter()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "chevron.right.2")
                                .font(.title2)
                            Text("下一章")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .disabled(currentChapterIndex >= (epubContent?.chapters.count ?? 1) - 1)
                    .opacity(currentChapterIndex >= (epubContent?.chapters.count ?? 1) - 1 ? 0.5 : 1)
                }
                .padding(.vertical, 8)
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
    
    // MARK: - 计算属性
    private var backgroundColor: Color {
        switch settings.backgroundColor {
        case "sepia":
            return Color(hex: "F4ECD8")
        case "light":
            return Color.white
        default:
            return Color(hex: "1a1a2e")
        }
    }
    
    private var textColor: Color {
        switch settings.backgroundColor {
        case "sepia":
            return Color(hex: "5B4636")
        case "light":
            return Color.black
        default:
            return Color.white
        }
    }
    
    private var currentFont: Font {
        if settings.fontFamily == "System" {
            return .system(size: settings.fontSize)
        } else {
            return .custom(settings.fontFamily, size: settings.fontSize)
        }
    }
    
    private var currentChapterTitle: String {
        guard let content = epubContent,
              currentChapterIndex < content.chapters.count else {
            return ""
        }
        return content.chapters[currentChapterIndex].title
    }
    
    // MARK: - 方法
    private func loadBook() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let filePath = book.filePath else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            let content = EPUBParser.parseContent(from: filePath)
            
            DispatchQueue.main.async {
                epubContent = content
                
                // 恢复阅读进度
                if let progress = ReadingProgress.load(for: book.id) {
                    currentChapterIndex = min(progress.chapterIndex, (content?.chapters.count ?? 1) - 1)
                }
                
                paginateCurrentChapter()
                isLoading = false
            }
        }
    }
    
    private func paginateCurrentChapter() {
        guard let content = epubContent,
              currentChapterIndex < content.chapters.count else {
            pages = []
            return
        }
        
        let chapter = content.chapters[currentChapterIndex]
        pages = paginateText(chapter.content)
        
        // 恢复页面位置
        if let progress = ReadingProgress.load(for: book.id),
           progress.chapterIndex == currentChapterIndex {
            currentPageIndex = min(progress.pageIndex, pages.count - 1)
        } else {
            currentPageIndex = 0
        }
    }
    
    private func paginateText(_ text: String) -> [String] {
        // 简单分页：按字符数分割
        let charsPerPage = Int(3000 / settings.fontSize * 18) // 估算每页字符数
        
        guard !text.isEmpty else { return [""] }
        
        var pages: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: charsPerPage, limitedBy: text.endIndex) ?? text.endIndex
            
            // 尝试在段落或句子边界分割
            var actualEndIndex = endIndex
            if actualEndIndex < text.endIndex {
                // 查找最近的段落分隔符
                if let paragraphBreak = text[currentIndex..<endIndex].lastIndex(of: "\n") {
                    actualEndIndex = text.index(after: paragraphBreak)
                }
                // 或者查找句号
                else if let sentenceBreak = text[currentIndex..<endIndex].lastIndex(where: { "。！？.!?".contains($0) }) {
                    actualEndIndex = text.index(after: sentenceBreak)
                }
            }
            
            let pageText = String(text[currentIndex..<actualEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !pageText.isEmpty {
                pages.append(pageText)
            }
            currentIndex = actualEndIndex
        }
        
        return pages.isEmpty ? [""] : pages
    }
    
    private func nextPage() {
        if currentPageIndex < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPageIndex += 1
            }
        } else {
            // 下一章
            nextChapter()
        }
        saveProgress()
    }
    
    private func previousPage() {
        if currentPageIndex > 0 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPageIndex -= 1
            }
        } else {
            // 上一章的最后一页
            if currentChapterIndex > 0 {
                currentChapterIndex -= 1
                paginateCurrentChapter()
                currentPageIndex = max(0, pages.count - 1)
            }
        }
        saveProgress()
    }
    
    private func nextChapter() {
        guard let content = epubContent,
              currentChapterIndex < content.chapters.count - 1 else { return }
        
        currentChapterIndex += 1
        paginateCurrentChapter()
        currentPageIndex = 0
        saveProgress()
    }
    
    private func previousChapter() {
        guard currentChapterIndex > 0 else { return }
        
        currentChapterIndex -= 1
        paginateCurrentChapter()
        currentPageIndex = 0
        saveProgress()
    }
    
    private func goToChapter(_ index: Int) {
        guard let content = epubContent,
              index >= 0 && index < content.chapters.count else { return }
        
        currentChapterIndex = index
        paginateCurrentChapter()
        currentPageIndex = 0
        saveProgress()
    }
    
    private func saveProgress() {
        let progress = ReadingProgress(
            bookId: book.id,
            chapterIndex: currentChapterIndex,
            pageIndex: currentPageIndex,
            scrollOffset: 0,
            lastReadDate: Date()
        )
        progress.save()
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

// MARK: - 阅读器设置视图
struct ReaderSettingsView: View {
    @Binding var settings: ReaderSettings
    @Environment(\.dismiss) private var dismiss
    
    let fontFamilies = ["System", "PingFang SC", "Heiti SC", "STSong", "Kaiti SC"]
    let backgroundOptions = [
        ("dark", "深色", Color(hex: "1a1a2e")),
        ("sepia", "护眼", Color(hex: "F4ECD8")),
        ("light", "浅色", Color.white)
    ]
    
    var body: some View {
        NavigationStack {
            List {
                // 字体大小
                Section("字体大小") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("A")
                                .font(.system(size: 14))
                            Slider(value: $settings.fontSize, in: 14...28, step: 1)
                            Text("A")
                                .font(.system(size: 28))
                        }
                        
                        Text("当前字号：\(Int(settings.fontSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // 字体选择
                Section("字体") {
                    Picker("字体", selection: $settings.fontFamily) {
                        ForEach(fontFamilies, id: \.self) { family in
                            Text(family)
                                .font(family == "System" ? .system(size: 16) : .custom(family, size: 16))
                                .tag(family)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // 行间距
                Section("行间距") {
                    VStack(alignment: .leading, spacing: 12) {
                        Slider(value: $settings.lineSpacing, in: 4...16, step: 2)
                        Text("当前行距：\(Int(settings.lineSpacing))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // 背景色
                Section("背景色") {
                    HStack(spacing: 16) {
                        ForEach(backgroundOptions, id: \.0) { option in
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(option.2)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(settings.backgroundColor == option.0 ? Color.blue : Color.gray.opacity(0.3), lineWidth: 3)
                                    )
                                    .onTapGesture {
                                        settings.backgroundColor = option.0
                                    }
                                
                                Text(option.1)
                                    .font(.caption)
                                    .foregroundColor(settings.backgroundColor == option.0 ? .blue : .secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // 文字对齐
                Section("文字对齐") {
                    Picker("对齐方式", selection: $settings.textAlignment) {
                        Text("左对齐").tag(TextAlignment.leading)
                        Text("居中").tag(TextAlignment.center)
                        Text("右对齐").tag(TextAlignment.trailing)
                    }
                    .pickerStyle(.segmented)
                }
                
                // 翻页效果
                Section("翻页效果") {
                    Picker("翻页样式", selection: $settings.pageTurnStyle) {
                        ForEach(PageTurnStyle.allCases, id: \.self) { style in
                            HStack {
                                Image(systemName: iconForPageStyle(style))
                                Text(style.name)
                            }
                            .tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(descriptionForPageStyle(settings.pageTurnStyle))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                // 预览
                Section("预览") {
                    Text("这是一段预览文字，用于展示当前的阅读设置效果。调整上方的设置可以实时看到变化。")
                        .font(previewFont)
                        .lineSpacing(settings.lineSpacing)
                        .multilineTextAlignment(settings.textAlignment)
                        .padding()
                        .background(previewBackground)
                        .foregroundColor(previewTextColor)
                        .cornerRadius(8)
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        settings.save()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var previewFont: Font {
        if settings.fontFamily == "System" {
            return .system(size: settings.fontSize)
        } else {
            return .custom(settings.fontFamily, size: settings.fontSize)
        }
    }
    
    private var previewBackground: Color {
        switch settings.backgroundColor {
        case "sepia": return Color(hex: "F4ECD8")
        case "light": return Color.white
        default: return Color(hex: "1a1a2e")
        }
    }
    
    private var previewTextColor: Color {
        switch settings.backgroundColor {
        case "sepia": return Color(hex: "5B4636")
        case "light": return Color.black
        default: return Color.white
        }
    }
    
    // 翻页样式图标
    private func iconForPageStyle(_ style: PageTurnStyle) -> String {
        switch style {
        case .slide: return "arrow.left.arrow.right"
        case .curl: return "book.pages"
        case .fade: return "sparkles"
        }
    }
    
    // 翻页样式描述
    private func descriptionForPageStyle(_ style: PageTurnStyle) -> String {
        switch style {
        case .slide: return "左右滑动切换页面，流畅自然"
        case .curl: return "模拟真实书本翻页效果，带3D动画"
        case .fade: return "页面淡入淡出切换，简洁优雅"
        }
    }
}

// MARK: - 目录视图
struct TOCView: View {
    let chapters: [EPUBChapter]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        onSelect(index)
                    } label: {
                        HStack {
                            Text(chapter.title)
                                .foregroundColor(index == currentIndex ? .blue : .primary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            if index == currentIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 真正的卷页效果视图（使用 UIPageViewController）
struct PageCurlView<Content: View>: View {
    let pages: [String]
    @Binding var currentPageIndex: Int
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let backgroundColor: Color
    let pageContent: (Int) -> Content
    let onPageChange: () -> Void
    let onTapCenter: () -> Void
    
    var body: some View {
        ZStack {
            // 使用 UIPageViewController 实现真正的卷页效果
            PageCurlViewController(
                pages: pages,
                currentPageIndex: $currentPageIndex,
                backgroundColor: UIColor(backgroundColor),
                pageContent: { index in
                    AnyView(pageContent(index))
                },
                onPageChange: onPageChange,
                onTapCenter: onTapCenter
            )
            .frame(width: pageWidth, height: pageHeight)
        }
    }
}

// MARK: - UIPageViewController 包装器（真正的卷页效果）
struct PageCurlViewController: UIViewControllerRepresentable {
    let pages: [String]
    @Binding var currentPageIndex: Int
    let backgroundColor: UIColor
    let pageContent: (Int) -> AnyView
    let onPageChange: () -> Void
    let onTapCenter: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .pageCurl,  // 真正的卷页效果
            navigationOrientation: .horizontal,
            options: [.spineLocation: NSNumber(value: UIPageViewController.SpineLocation.min.rawValue)]
        )
        
        pageViewController.delegate = context.coordinator
        pageViewController.dataSource = context.coordinator
        pageViewController.view.backgroundColor = backgroundColor
        
        // 设置初始页面
        if let initialVC = context.coordinator.viewController(at: currentPageIndex) {
            pageViewController.setViewControllers([initialVC], direction: .forward, animated: false)
        }
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        pageViewController.view.addGestureRecognizer(tapGesture)
        
        return pageViewController
    }
    
    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        // 更新当前页面索引
        context.coordinator.parent = self
        
        // 如果页面索引发生变化，更新显示
        if let currentVC = pageViewController.viewControllers?.first as? PageContentViewController,
           currentVC.pageIndex != currentPageIndex {
            if let newVC = context.coordinator.viewController(at: currentPageIndex) {
                let direction: UIPageViewController.NavigationDirection = currentVC.pageIndex < currentPageIndex ? .forward : .reverse
                pageViewController.setViewControllers([newVC], direction: direction, animated: true)
            }
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
        var parent: PageCurlViewController
        
        init(_ parent: PageCurlViewController) {
            self.parent = parent
        }
        
        // 创建页面内容视图控制器
        func viewController(at index: Int) -> PageContentViewController? {
            guard index >= 0 && index < parent.pages.count else { return nil }
            
            let vc = PageContentViewController()
            vc.pageIndex = index
            vc.view.backgroundColor = parent.backgroundColor
            
            // 添加 SwiftUI 内容
            let hostingController = UIHostingController(rootView: parent.pageContent(index))
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = vc.view.bounds
            hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            vc.addChild(hostingController)
            vc.view.addSubview(hostingController.view)
            hostingController.didMove(toParent: vc)
            
            return vc
        }
        
        // MARK: - UIPageViewControllerDataSource
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? PageContentViewController else { return nil }
            return self.viewController(at: vc.pageIndex - 1)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? PageContentViewController else { return nil }
            return self.viewController(at: vc.pageIndex + 1)
        }
        
        // MARK: - UIPageViewControllerDelegate
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed,
               let currentVC = pageViewController.viewControllers?.first as? PageContentViewController {
                parent.currentPageIndex = currentVC.pageIndex
                parent.onPageChange()
            }
        }
        
        // MARK: - 手势处理
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let width = gesture.view?.bounds.width ?? 0
            
            if location.x < width * 0.25 {
                // 左侧点击 - 上一页
                if parent.currentPageIndex > 0 {
                    parent.currentPageIndex -= 1
                    parent.onPageChange()
                }
            } else if location.x > width * 0.75 {
                // 右侧点击 - 下一页
                if parent.currentPageIndex < parent.pages.count - 1 {
                    parent.currentPageIndex += 1
                    parent.onPageChange()
                }
            } else {
                // 中间点击 - 显示/隐藏控制栏
                parent.onTapCenter()
            }
        }
    }
}

// MARK: - 页面内容视图控制器
class PageContentViewController: UIViewController {
    var pageIndex: Int = 0
}

// MARK: - 预览
#Preview {
    ReaderView(book: Book(
        id: "preview",
        title: "预览书籍",
        author: "作者",
        coverURL: nil,
        filePath: nil,
        addedDate: nil
    ))
}
