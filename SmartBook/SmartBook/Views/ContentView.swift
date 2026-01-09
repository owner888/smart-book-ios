// ContentView.swift - 主视图（支持主题切换）

import SwiftUI
import UniformTypeIdentifiers

// Tab 枚举
enum AppTab: String, CaseIterable {
    case bookshelf = "书架"
    case chat = "对话"
    case settings = "设置"
    case search = "搜索"
    
    var icon: String {
        switch self {
        case .bookshelf: return "books.vertical"
        case .chat: return "bubble.left.and.bubble.right"
        case .settings: return "gear"
        case .search: return "magnifyingglass"
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @State private var selectedTab: AppTab = .bookshelf
    @State private var previousTab: AppTab = .bookshelf
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Primary Tabs
            Tab(AppTab.bookshelf.rawValue, systemImage: AppTab.bookshelf.icon, value: .bookshelf) {
                BookshelfView()
            }
            
            Tab(AppTab.chat.rawValue, systemImage: AppTab.chat.icon, value: .chat) {
                ChatView()
            }
            
            Tab(AppTab.settings.rawValue, systemImage: AppTab.settings.icon, value: .settings) {
                SettingsView()
            }
            
            // Standalone Search Tab - 进入 Search Landing Page，TabBar 保留
            Tab(value: .search, role: .search) {
                SearchView(
                    previousTabIcon: previousTab.icon,
                    previousTabName: previousTab.rawValue,
                    onBack: {
                        selectedTab = previousTab
                    }
                )
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // 记录上一个非搜索 Tab
            if newValue != .search {
                previousTab = newValue
            }
        }
        .animation(.smooth(duration: 0.35), value: selectedTab)  // Tab 切换动画
    }
}

// MARK: - 书架视图
struct BookshelfView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var books: [Book] = []
    @State private var isLoading = false
    @State private var showingImporter = false
    @State private var showingDeleteAlert = false
    @State private var bookToDelete: Book?
    @State private var importError: String?
    @State private var showingError = false
    @State private var selectedBookForReading: Book?
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(colors.primaryText)
                        Text("正在加载书籍...")
                            .foregroundColor(colors.secondaryText)
                    }
                } else if books.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(colors.secondaryText)
                        Text("暂无书籍")
                            .font(.headline)
                            .foregroundColor(colors.secondaryText)
                        Text("点击右上角 + 按钮导入 epub 书籍")
                            .font(.caption)
                            .foregroundColor(colors.secondaryText.opacity(0.7))
                        
                        Button {
                            showingImporter = true
                        } label: {
                            Label("导入书籍", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(25)
                        }
                    }
                } else {
                    ScrollView {
                        HStack {
                            Text("共 \(books.count) 本书")
                                .font(.subheadline)
                                .foregroundColor(colors.secondaryText)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(books) { book in
                                BookCard(book: book, isUserImported: appState.bookService.isUserImportedBook(book), colors: colors)
                                    .onTapGesture {
                                        if book.filePath != nil {
                                            selectedBookForReading = book
                                        } else {
                                            appState.selectedBook = book
                                        }
                                    }
                                    .contextMenu {
                                        if book.filePath != nil {
                                            Button {
                                                selectedBookForReading = book
                                            } label: {
                                                Label("阅读", systemImage: "book")
                                            }
                                        }
                                        
                                        Button {
                                            appState.selectedBook = book
                                        } label: {
                                            Label("AI 对话", systemImage: "bubble.left.and.bubble.right")
                                        }
                                        
                                        if appState.bookService.isUserImportedBook(book) {
                                            Button(role: .destructive) {
                                                bookToDelete = book
                                                showingDeleteAlert = true
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("书架")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(colors.primaryText)
                    }
                }
            }
            .task {
                await loadBooks()
            }
            .refreshable {
                await loadBooks()
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
                allowsMultipleSelection: true
            ) { result in
                Task {
                    await handleImport(result)
                }
            }
            .alert("删除书籍", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let book = bookToDelete {
                        deleteBook(book)
                    }
                }
            } message: {
                Text("确定要删除「\(bookToDelete?.title ?? "")」吗？此操作不可恢复。")
            }
            .alert("导入失败", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(importError ?? "未知错误")
            }
            .fullScreenCover(item: $selectedBookForReading) { book in
                ReaderView(book: book)
            }
        }
    }
    
    func loadBooks() async {
        isLoading = true
        do {
            books = try await appState.bookService.fetchBooks()
        } catch {
            appState.errorMessage = error.localizedDescription
            books = appState.bookService.loadLocalBooks()
        }
        isLoading = false
    }
    
    func handleImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            var importedCount = 0
            for url in urls {
                do {
                    _ = try appState.bookService.importBook(from: url)
                    importedCount += 1
                } catch {
                    importError = "导入失败: \(error.localizedDescription)"
                    showingError = true
                }
            }
            if importedCount > 0 {
                await loadBooks()
            }
        case .failure(let error):
            importError = "选择文件失败: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    func deleteBook(_ book: Book) {
        do {
            try appState.bookService.deleteBook(book)
            books.removeAll { $0.id == book.id }
        } catch {
            importError = "删除失败: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - 书籍卡片
struct BookCard: View {
    let book: Book
    var isUserImported: Bool = false
    var colors: ThemeColors = .dark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                coverImage
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if isUserImported {
                    Text("已导入")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(6)
                }
            }
            
            Text(book.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(colors.primaryText)
            
            Text(book.author)
                .font(.caption)
                .foregroundColor(colors.secondaryText)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(colors.cardBackground)
        }
    }
    
    @ViewBuilder
    var coverImage: some View {
        if let coverURLString = book.coverURL,
           let coverURL = URL(string: coverURLString) {
            if coverURL.isFileURL {
                if let uiImage = UIImage(contentsOfFile: coverURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderCover
                }
            } else {
                AsyncImage(url: coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderCover
                }
            }
        } else {
            placeholderCover
        }
    }
    
    var placeholderCover: some View {
        Rectangle()
            .fill(colors.inputBackground)
            .overlay {
                Image(systemName: "book.closed")
                    .font(.largeTitle)
                    .foregroundColor(colors.secondaryText)
            }
    }
}

// MARK: - 颜色扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
}
