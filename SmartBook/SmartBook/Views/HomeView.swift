// HomeView.swift - 首页视图

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var recentBooks: [Book] = []
    @State private var favoriteBooks: [Book] = []
    @State private var readingStats: ReadingStats = ReadingStats()
    @State private var selectedBookForReading: Book?
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 阅读时间统计
                        ReadingStatsCard(stats: readingStats, colors: colors)
                            .padding(.horizontal)
                        
                        // 继续阅读
                        if !recentBooks.isEmpty {
                            ContinueReadingSection(books: recentBooks, colors: colors) { book in
                                selectedBookForReading = book
                            }
                        }
                        
                        // 收藏
                        if !favoriteBooks.isEmpty {
                            FavoritesSection(books: favoriteBooks, colors: colors) { book in
                                selectedBookForReading = book
                            }
                        }
                        
                        // 空状态
                        if recentBooks.isEmpty && favoriteBooks.isEmpty {
                            EmptyHomeState(colors: colors)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(L("tab.home"))
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadData()
                loadReadingStats()
            }
            .fullScreenCover(item: $selectedBookForReading) { book in
                ReaderView(book: book)
            }
        }
    }
    
    func loadData() async {
        let books = appState.bookService.loadLocalBooks()
        recentBooks = Array(books.prefix(5))
        favoriteBooks = books.filter { $0.isFavorite }
    }
    
    func loadReadingStats() {
        readingStats = appState.bookService.loadReadingStats()
    }
}

// MARK: - 阅读统计卡片
struct ReadingStatsCard: View {
    let stats: ReadingStats
    var colors: ThemeColors
    
    var body: some View {
        VStack(spacing: 16) {
            Text(L("home.readingStats"))
                .font(.headline)
                .foregroundColor(colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 0) {
                StatItem(
                    value: "\(stats.totalBooksRead)",
                    label: L("home.booksRead"),
                    colors: colors
                )
                
                Divider()
                    .frame(height: 40)
                    .background(colors.separator)
                
                StatItem(
                    value: stats.formattedTotalTime,
                    label: L("home.totalTime"),
                    colors: colors
                )
                
                Divider()
                    .frame(height: 40)
                    .background(colors.separator)
                
                StatItem(
                    value: "\(stats.currentStreak)",
                    label: L("home.streak"),
                    colors: colors
                )
            }
            .padding(.vertical, 8)
            
            // 今日阅读进度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L("home.todayReading"))
                        .font(.caption)
                        .foregroundColor(colors.secondaryText)
                    Spacer()
                    Text(stats.formattedTodayTime)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colors.inputBackground)
                            .frame(height: 8)
                        
                        let progress = min(CGFloat(stats.todayMinutes) / 60.0, 1.0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.gradient)
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(colors.cardBackground)
        .cornerRadius(16)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    var colors: ThemeColors
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colors.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundColor(colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 继续阅读区域
struct ContinueReadingSection: View {
    let books: [Book]
    var colors: ThemeColors
    let onSelect: (Book) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("home.continueReading"))
                    .font(.headline)
                    .foregroundColor(colors.primaryText)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(books) { book in
                        ContinueReadingCard(book: book, colors: colors)
                            .onTapGesture {
                                onSelect(book)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ContinueReadingCard: View {
    let book: Book
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 12) {
            bookCover
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(colors.primaryText)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
                
                // 阅读进度
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(book.progressText)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(colors.secondaryText)
        }
        .padding(12)
        .background(colors.cardBackground)
        .cornerRadius(12)
        .frame(width: 240)
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
}

// MARK: - 收藏区域
struct FavoritesSection: View {
    let books: [Book]
    var colors: ThemeColors
    let onSelect: (Book) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("home.favorites"))
                    .font(.headline)
                    .foregroundColor(colors.primaryText)
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(books) { book in
                    FavoriteBookCard(book: book, colors: colors)
                        .onTapGesture {
                            onSelect(book)
                        }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FavoriteBookCard: View {
    let book: Book
    var colors: ThemeColors
    
    var body: some View {
        VStack(spacing: 6) {
            bookCover
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(book.title)
                .font(.caption)
                .foregroundColor(colors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
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
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(colors.secondaryText)
                }
        }
    }
}

// MARK: - 空状态
struct EmptyHomeState: View {
    var colors: ThemeColors
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 50))
                .foregroundColor(colors.secondaryText)
            
            Text(L("home.empty"))
                .font(.headline)
                .foregroundColor(colors.secondaryText)
            
            Text(L("home.emptyTip"))
                .font(.caption)
                .foregroundColor(colors.secondaryText.opacity(0.7))
        }
        .padding(.vertical, 60)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .environment(ThemeManager.shared)
}
