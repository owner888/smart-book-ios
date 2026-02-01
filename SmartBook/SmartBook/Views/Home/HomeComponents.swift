// HomeComponents.swift - 首页子组件集合

import SwiftUI

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
            TodayReadingProgress(stats: stats, colors: colors)
        }
        .padding()
        .background(colors.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - 统计项
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

// MARK: - 今日阅读进度
struct TodayReadingProgress: View {
    let stats: ReadingStats
    var colors: ThemeColors
    
    var body: some View {
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

// MARK: - 继续阅读卡片
struct ContinueReadingCard: View {
    let book: Book
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(book: book, colors: colors)
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

// MARK: - 收藏书籍卡片
struct FavoriteBookCard: View {
    let book: Book
    var colors: ThemeColors
    
    var body: some View {
        VStack(spacing: 6) {
            BookCoverView(book: book, colors: colors)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(book.title)
                .font(.caption)
                .foregroundColor(colors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - 空状态
struct EmptyHomeState: View {
    var colors: ThemeColors
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 50)) // 装饰性大图标
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

// MARK: - 签到按钮
struct CheckInButton: View {
    let isCheckedIn: Bool
    let streak: String
    var colors: ThemeColors
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "calendar.badge.checkmark")
                    .foregroundColor(isCheckedIn ? .green : .orange)
                Text(streak)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(colors.primaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colors.cardBackground)
            .cornerRadius(12)
        }
        .disabled(isCheckedIn)
    }
}
