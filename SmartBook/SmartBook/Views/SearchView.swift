// SearchView.swift - 搜索视图（支持多语言）

import SwiftUI

struct SearchView: View {
    @Environment(BookState.self) var bookState
    @Environment(ThemeManager.self) var themeManager
    @Environment(BookService.self) var bookService
    @Environment(\.colorScheme) var systemColorScheme
    @State private var searchText = ""
    @State private var books: [Book] = []
    @State private var selectedBookForReading: Book?
    @State private var recentSearches: [String] = []
    @FocusState private var isSearchFocused: Bool
    @State private var isPresented = false
    
    var previousTabIcon: String = "books.vertical"
    var previousTabName: String = "书架"
    var onBack: (() -> Void)?
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    private let categories: [(name: String, color: Color, icon: String)] = [
        ("search.category.classics", .red, "book.fill"),
        ("search.category.history", .orange, "clock.fill"),
        ("search.category.wuxia", .purple, "figure.martial.arts"),
        ("search.category.romance", .pink, "heart.fill"),
        ("search.category.scifi", .blue, "sparkles"),
        ("search.category.mystery", .indigo, "magnifyingglass"),
        ("search.category.literature", .green, "leaf.fill"),
        ("search.category.modern", .cyan, "building.2.fill")
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
                    mainContent
                }
            }
            .navigationTitle(L("search.title"))
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadBooks()
                loadRecentSearches()
            }
            .fullScreenCover(item: $selectedBookForReading) { book in
                ReaderView(book: book)
            }
        }.searchable(text: $searchText, prompt: L("search.placeholder"))
    }
    
    @ViewBuilder
    var mainContent: some View {
        ScrollView {
            if searchText.isEmpty {
                if isPresented {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(L("search.recentSearches"))
                                .font(.headline)
                                .foregroundColor(colors.primaryText)
                            Spacer()
                            Button(L("search.clear")) {
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
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(categories, id: \.name) { category in
                            CategoryCard(name: L(category.name), color: category.color, icon: category.icon)
                                .onTapGesture {
                                    searchText = L(category.name)
                                }
                        }
                    }
                    .padding()
                }
            
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if filteredBooks.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)
                            Image(systemName: "book.closed")
                                .font(.system(size: 50))
                                .foregroundColor(colors.secondaryText)
                            Text(String(format: L("search.noResultsFor"), searchText))
                                .font(.headline)
                                .foregroundColor(colors.primaryText)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(String(format: L("search.foundBooks"), filteredBooks.count))
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
                                        bookState.selectedBook = book
                                    }
                                }
                        }
                    }
                }
                .padding(.top)
            }
        }
    }
    
    func loadBooks() async {
        do {
            books = try await bookService.fetchBooks()
        } catch {
            books = bookService.loadLocalBooks()
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

struct SearchResultRow: View {
    let book: Book
    let searchText: String
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(book: book, colors: colors)
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                highlightedText(book.title, searchText: searchText, baseColor: colors.primaryText)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(String(format: L("search.bookAuthor"), book.author))
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
            }
            
            Spacer()
            
            Button {
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(colors.secondaryText)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
        .environment(BookState())
        .environment(ThemeManager.shared)
}
