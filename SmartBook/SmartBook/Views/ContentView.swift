// ContentView.swift - 主视图（Liquid Glass 风格）

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppState.self) var appState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 书架
            BookshelfView()
                .tabItem {
                    Label("书架", systemImage: "books.vertical")
                }
                .tag(0)
            
            // AI 对话
            ChatView()
                .tabItem {
                    Label("对话", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(1)
            
            // 设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(.white)
    }
}

// MARK: - 书架视图
struct BookshelfView: View {
    @Environment(AppState.self) var appState
    @State private var books: [Book] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var showingImporter = false
    @State private var showingDeleteAlert = false
    @State private var bookToDelete: Book?
    @State private var importError: String?
    @State private var showingError = false
    @State private var selectedBookForReading: Book?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    // 加载中状态
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("正在加载书籍...")
                            .foregroundColor(.gray)
                    }
                } else if books.isEmpty {
                    // 空状态
                    VStack(spacing: 20) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("暂无书籍")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("点击右上角 + 按钮导入 epub 书籍")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                        
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
                        // 书籍数量统计
                        HStack {
                            Text("共 \(filteredBooks.count) 本书")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(filteredBooks) { book in
                                BookCard(book: book, isUserImported: appState.bookService.isUserImportedBook(book))
                                    .onTapGesture {
                                        // 如果有文件路径，打开阅读器
                                        if book.filePath != nil {
                                            selectedBookForReading = book
                                        } else {
                                            appState.selectedBook = book
                                        }
                                    }
                                    .contextMenu {
                                        // 阅读
                                        if book.filePath != nil {
                                            Button {
                                                selectedBookForReading = book
                                            } label: {
                                                Label("阅读", systemImage: "book")
                                            }
                                        }
                                        
                                        // AI 对话
                                        Button {
                                            appState.selectedBook = book
                                        } label: {
                                            Label("AI 对话", systemImage: "bubble.left.and.bubble.right")
                                        }
                                        
                                        // 删除
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索书籍")
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
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books
        }
        return books.filter { 
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func loadBooks() async {
        isLoading = true
        do {
            books = try await appState.bookService.fetchBooks()
        } catch {
            appState.errorMessage = error.localizedDescription
            // 如果 API 失败，尝试直接加载本地书籍
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

// MARK: - 书籍卡片（Liquid Glass 风格）
struct BookCard: View {
    let book: Book
    var isUserImported: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面
            ZStack(alignment: .topTrailing) {
                coverImage
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 用户导入标识
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
            
            // 标题
            Text(book.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.white)
            
            // 作者
            Text(book.author)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background {
            // Liquid Glass 效果
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        }
    }
    
    /// 封面图片视图
    @ViewBuilder
    var coverImage: some View {
        if let coverURLString = book.coverURL,
           let coverURL = URL(string: coverURLString) {
            // 本地文件封面
            if coverURL.isFileURL {
                if let uiImage = UIImage(contentsOfFile: coverURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderCover
                }
            } else {
                // 网络封面
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
    
    /// 占位封面
    var placeholderCover: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "book.closed")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
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
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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
}
