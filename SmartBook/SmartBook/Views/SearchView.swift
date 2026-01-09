// SearchView.swift - 搜索视图（按书名/作者搜索书籍）

import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var searchText = ""
    @State private var books: [Book] = []
    @State private var isLoading = true
    @State private var selectedBookForReading: Book?
    @FocusState private var isSearchFocused: Bool
    
    // 记录来源页面
    var previousTabIcon: String = "books.vertical"
    var previousTabName: String = "书架"
    var onBack: (() -> Void)?
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return []
        }
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
                    if searchText.isEmpty {
                        // 空状态：显示提示
                        placeholderView
                    } else if filteredBooks.isEmpty {
                        // 无结果
                        emptyResultView
                    } else {
                        // 搜索结果列表
                        resultsList
                    }
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onBack?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: previousTabIcon)
                                .font(.body)
                            Text(previousTabName)
                                .font(.body)
                        }
                        .foregroundColor(colors.primaryText)
                    }
                }
            }
            .searchable(text: $searchText, isPresented: .constant(true), prompt: "书名、作者")
            .task {
                await loadBooks()
                // 自动聚焦搜索框
                isSearchFocused = true
            }
            .fullScreenCover(item: $selectedBookForReading) { book in
                ReaderView(book: book)
            }
        }
    }
    
    // MARK: - 占位视图
    var placeholderView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(colors.secondaryText.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("搜索书籍")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(colors.primaryText)
                
                Text("输入书名或作者名来查找书籍")
                    .font(.subheadline)
                    .foregroundColor(colors.secondaryText)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 空结果视图
    var emptyResultView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(colors.secondaryText)
            
            Text("未找到「\(searchText)」")
                .font(.headline)
                .foregroundColor(colors.primaryText)
            
            Text("尝试不同的关键词")
                .font(.subheadline)
                .foregroundColor(colors.secondaryText)
            
            Spacer()
        }
    }
    
    // MARK: - 搜索结果列表
    var resultsList: some View {
        List {
            Section {
                ForEach(filteredBooks) { book in
                    SearchBookRow(book: book, searchText: searchText, colors: colors)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if book.filePath != nil {
                                selectedBookForReading = book
                            } else {
                                appState.selectedBook = book
                            }
                        }
                        .listRowBackground(colors.cardBackground)
                }
            } header: {
                Text("找到 \(filteredBooks.count) 本书")
                    .foregroundColor(colors.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - 方法
    func loadBooks() async {
        isLoading = true
        do {
            books = try await appState.bookService.fetchBooks()
        } catch {
            books = appState.bookService.loadLocalBooks()
        }
        isLoading = false
    }
}

// MARK: - 搜索结果书籍行
struct SearchBookRow: View {
    let book: Book
    let searchText: String
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面缩略图
            bookCover
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // 书籍信息
            VStack(alignment: .leading, spacing: 4) {
                // 高亮标题
                highlightedText(book.title, searchText: searchText, baseColor: colors.primaryText)
                    .font(.headline)
                    .lineLimit(2)
                
                // 高亮作者
                highlightedText(book.author, searchText: searchText, baseColor: colors.secondaryText)
                    .font(.caption)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(colors.secondaryText)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    var bookCover: some View {
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
                    .foregroundColor(colors.secondaryText)
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
        
        // 不区分大小写查找所有匹配项
        let lowercasedText = text.lowercased()
        let lowercasedSearch = searchText.lowercased()
        
        var searchStart = lowercasedText.startIndex
        while let range = lowercasedText.range(of: lowercasedSearch, range: searchStart..<lowercasedText.endIndex) {
            // 转换为 AttributedString 的范围
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
