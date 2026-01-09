// SearchView.swift - Apple Music 风格搜索视图
// Search Landing Page - 底部显示 Home 按钮 + 搜索框

import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var searchText = ""
    @State private var books: [Book] = []
    @State private var selectedBookForReading: Book?
    @State private var recentSearches: [String] = []
    @FocusState private var isSearchFocused: Bool
    
    // 来源页面信息
    var previousTabIcon: String = "books.vertical"
    var previousTabName: String = "书架"
    var onBack: (() -> Void)?
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    // 书籍分类
    private let categories: [(name: String, color: Color, icon: String)] = [
        ("四大名著", .red, "book.fill"),
        ("历史小说", .orange, "clock.fill"),
        ("武侠小说", .purple, "figure.martial.arts"),
        ("言情小说", .pink, "heart.fill"),
        ("科幻小说", .blue, "sparkles"),
        ("推理悬疑", .indigo, "magnifyingglass"),
        ("经典文学", .green, "leaf.fill"),
        ("现代小说", .cyan, "building.2.fill")
    ]
    
    var filteredBooks: [Book] {
        guard !searchText.isEmpty else { return [] }
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 主内容区域
                    mainContent
                    
                    // 底部搜索栏（固定）- 替代 TabBar
                    bottomSearchBar
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadBooks()
                loadRecentSearches()
            }
            .fullScreenCover(item: $selectedBookForReading) { book in
                ReaderView(book: book)
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)  // 隐藏 TabBar
        .animation(.easeInOut(duration: 0.3), value: searchText)  // 搜索内容切换动画
    }
    
    // MARK: - 主内容
    @ViewBuilder
    var mainContent: some View {
        ScrollView {
            if searchText.isEmpty {
                // 显示分类卡片
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(categories, id: \.name) { category in
                        CategoryCard(name: category.name, color: category.color, icon: category.icon)
                            .onTapGesture {
                                searchText = category.name
                            }
                    }
                }
                .padding()
                
                // 最近搜索
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("最近搜索")
                                .font(.headline)
                                .foregroundColor(colors.primaryText)
                            Spacer()
                            Button("清除") {
                                clearRecentSearches()
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                        
                        ForEach(recentSearches, id: \.self) { search in
                            RecentSearchRow(text: search, colors: colors)
                                .onTapGesture {
                                    searchText = search
                                }
                        }
                    }
                    .padding(.top)
                }
            } else {
                // 搜索结果
                VStack(alignment: .leading, spacing: 12) {
                    if filteredBooks.isEmpty {
                        // 无结果
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)
                            Image(systemName: "book.closed")
                                .font(.system(size: 50))
                                .foregroundColor(colors.secondaryText)
                            Text("未找到「\(searchText)」")
                                .font(.headline)
                                .foregroundColor(colors.primaryText)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("找到 \(filteredBooks.count) 本书")
                            .font(.headline)
                            .foregroundColor(colors.primaryText)
                            .padding(.horizontal)
                        
                        ForEach(filteredBooks) { book in
                            SearchResultRow(book: book, searchText: searchText, colors: colors)
                                .onTapGesture {
                                    addToRecentSearches(searchText)
                                    if book.filePath != nil {
                                        selectedBookForReading = book
                                    } else {
                                        appState.selectedBook = book
                                    }
                                }
                        }
                    }
                }
                .padding(.top)
            }
        }
    }
    
    // MARK: - 底部搜索栏（替代 TabBar）
    var bottomSearchBar: some View {
        HStack(spacing: 12) {
            // Home 返回按钮
            Button {
                onBack?()
            } label: {
                Image(systemName: previousTabIcon)
                    .font(.title2)
                    .foregroundColor(colors.primaryText)
                    .frame(width: 44, height: 44)
                    .background(colors.cardBackground)
                    .clipShape(Circle())
            }
            
            // 搜索输入框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(colors.secondaryText)
                
                TextField("书名、作者", text: $searchText)
                    .foregroundColor(colors.primaryText)
                    .focused($isSearchFocused)
                
                // 语音按钮
                Button {
                    // TODO: 语音搜索
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundColor(colors.secondaryText)
                }
                
                // 清除按钮
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(colors.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(colors.cardBackground)
            .cornerRadius(25)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            colors.background
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - 方法
    func loadBooks() async {
        do {
            books = try await appState.bookService.fetchBooks()
        } catch {
            books = appState.bookService.loadLocalBooks()
        }
    }
    
    func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
    }
    
    func addToRecentSearches(_ text: String) {
        guard !text.isEmpty else { return }
        var searches = recentSearches
        searches.removeAll { $0 == text }
        searches.insert(text, at: 0)
        if searches.count > 5 {
            searches = Array(searches.prefix(5))
        }
        recentSearches = searches
        UserDefaults.standard.set(searches, forKey: "RecentSearches")
    }
    
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "RecentSearches")
    }
}

// MARK: - 分类卡片
struct CategoryCard: View {
    let name: String
    let color: Color
    let icon: String
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.gradient)
                .frame(height: 100)
            
            HStack {
                VStack(alignment: .leading) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(12)
        }
    }
}

// MARK: - 最近搜索行
struct RecentSearchRow: View {
    let text: String
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .foregroundColor(colors.secondaryText)
            
            Text(text)
                .foregroundColor(colors.primaryText)
            
            Spacer()
            
            Image(systemName: "arrow.up.left")
                .font(.caption)
                .foregroundColor(colors.secondaryText)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(colors.cardBackground)
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let book: Book
    let searchText: String
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            bookCover
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                highlightedText(book.title, searchText: searchText, baseColor: colors.primaryText)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("书籍 · \(book.author)")
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
            }
            
            Spacer()
            
            Button {
                // 更多操作
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(colors.secondaryText)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    var bookCover: some View {
        if let coverURLString = book.coverURL,
           let coverURL = URL(string: coverURLString),
           coverURL.isFileURL,
           let uiImage = UIImage(contentsOfFile: coverURL.path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(colors.inputBackground)
                .overlay {
                    Image(systemName: "book.closed")
                        .foregroundColor(colors.secondaryText)
                }
        }
    }
    
    @ViewBuilder
    func highlightedText(_ text: String, searchText: String, baseColor: Color) -> some View {
        if searchText.isEmpty {
            Text(text).foregroundColor(baseColor)
        } else {
            Text(attributedString(for: text, searchText: searchText, baseColor: baseColor))
        }
    }
    
    func attributedString(for text: String, searchText: String, baseColor: Color) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = baseColor
        
        let lowercasedText = text.lowercased()
        let lowercasedSearch = searchText.lowercased()
        
        var searchStart = lowercasedText.startIndex
        while let range = lowercasedText.range(of: lowercasedSearch, range: searchStart..<lowercasedText.endIndex) {
            if let attrRange = Range(NSRange(range, in: text), in: result) {
                result[attrRange].foregroundColor = .orange
                result[attrRange].font = .headline.bold()
            }
            searchStart = range.upperBound
        }
        
        return result
    }
}

#Preview {
    SearchView()
        .environment(AppState())
        .environment(ThemeManager.shared)
}
