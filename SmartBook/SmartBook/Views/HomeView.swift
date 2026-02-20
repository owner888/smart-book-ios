// HomeView.swift - 首页视图（组件化重构版）

import SwiftUI

struct HomeView: View {
    @Environment(BookState.self) var bookState
    @Environment(ThemeManager.self) var themeManager
    @Environment(BookService.self) var bookService
    @Environment(CheckInService.self) var checkInService
    @Environment(\.colorScheme) var systemColorScheme

    // ViewModel
    @State private var viewModel: HomeViewModel

    init() {
        _viewModel = State(
            wrappedValue: HomeViewModel(
                bookService: BookService(),
                checkInService: CheckInService()
            )
        )
    }

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
                        ReadingStatsCard(stats: viewModel.readingStats, colors: colors)
                            .padding(.horizontal)

                        // 继续阅读
                        if !viewModel.recentBooks.isEmpty {
                            ContinueReadingSection(
                                books: viewModel.recentBooks,
                                colors: colors
                            ) { book in
                                viewModel.selectBookForReading(book)
                            }
                        }

                        // 收藏
                        if !viewModel.favoriteBooks.isEmpty {
                            FavoritesSection(
                                books: viewModel.favoriteBooks,
                                colors: colors
                            ) { book in
                                viewModel.selectBookForReading(book)
                            }
                        }

                        // 空状态
                        if viewModel.recentBooks.isEmpty && viewModel.favoriteBooks.isEmpty {
                            EmptyHomeState(colors: colors)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(L("tab.home"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CheckInButton(
                        isCheckedIn: checkInService.isTodayCheckedIn,
                        streak: checkInService.formattedStreak,
                        colors: colors,
                        action: performCheckIn
                    )
                }
            }
            .task { [viewModel] in
                await viewModel.loadData()
                await viewModel.syncCloudKit()
            }
            .fullScreenCover(item: $viewModel.selectedBookForReading) { book in
                ReaderView(book: book)
            }
            .alert(viewModel.checkInMessage, isPresented: $viewModel.showingCheckInAlert) {
                Button(L("common.ok"), role: .cancel) {}
            }
        }
    }

    private func performCheckIn() {
        Task {
            await viewModel.checkIn()
        }
    }
}

#Preview {
    HomeView()
        .environment(BookState())
        .environment(ThemeManager.shared)
}
