// BookshelfView.swift - 书架视图

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 书架视图
struct BookshelfView: View {
    @Environment(BookState.self) var bookState
    @Environment(ThemeManager.self) var themeManager
    @Environment(BookService.self) var bookService
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dismiss) var dismiss
    
    // ViewModel - 使用 Environment 依赖注入
    @State private var viewModel: BookshelfViewModel
    
    init() {
        // 使用空的初始化，在 onAppear 中注入依赖
        _viewModel = State(wrappedValue: BookshelfViewModel(
            bookService: BookService(),
            bookState: BookState()
        ))
    }
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                
                contentView
            }
            .navigationTitle(L("library.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(colors.primaryText)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showImporter()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(colors.primaryText)
                    }
                }
            }
            .task {
                await viewModel.loadBooks()
            }
            .refreshable {
                await viewModel.loadBooks()
            }
            .fileImporter(
                isPresented: $viewModel.showingImporter,
                allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
                allowsMultipleSelection: true
            ) { result in
                Task {
                    await viewModel.handleImport(result)
                }
            }
            .alert(L("library.delete.title"), isPresented: $viewModel.showingDeleteAlert) {
                Button(L("common.cancel"), role: .cancel) { }
                Button(L("common.delete"), role: .destructive) {
                    if let book = viewModel.bookToDelete {
                        viewModel.deleteBook(book)
                    }
                }
            } message: {
                Text(L("library.delete.message"))
            }
            .alert(L("library.import.failed"), isPresented: $viewModel.showingError) {
                Button(L("common.ok"), role: .cancel) { }
            } message: {
                Text(viewModel.importError ?? L("error.generic"))
            }
            .fullScreenCover(item: $viewModel.selectedBookForReading) { book in
                ReaderView(book: book)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if bookState.isLoading {
            loadingView
        } else if bookState.books.isEmpty {
            emptyView
        } else {
            bookGridView
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(colors.primaryText)
            Text(L("common.loading"))
                .foregroundColor(colors.secondaryText)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60)) // 装饰性大图标
                .foregroundColor(colors.secondaryText)
            Text(L("library.empty"))
                .font(.headline)
                .foregroundColor(colors.secondaryText)
            Text(L("library.empty.tip"))
                .font(.caption)
                .foregroundColor(colors.secondaryText.opacity(0.7))
            
            Button {
                viewModel.showImporter()
            } label: {
                Label(L("library.import"), systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
        }
    }
    
    private var bookGridView: some View {
        ScrollView {
            HStack {
                Text(String(format: L("library.bookCount"), bookState.books.count))
                    .font(.subheadline)
                    .foregroundColor(colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            LazyVGrid(columns: gridColumns, spacing: horizontalSizeClass == .regular ? 36 : 24) {
                ForEach(bookState.books) { book in
                    BookCard(book: book, isUserImported: viewModel.isUserImportedBook(book), colors: colors)
                        .onTapGesture {
                            viewModel.selectBookForReading(book)
                        }
                        .contextMenu {
                            contextMenuItems(for: book)
                        }
                }
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 24)
            .padding(.vertical)
        }
    }
    
    @ViewBuilder
    private func contextMenuItems(for book: Book) -> some View {
        if book.filePath != nil {
            Button {
                viewModel.selectBookForReading(book)
            } label: {
                Label(L("reader.title"), systemImage: "book")
            }
        }
        
        Button {
            bookState.selectedBook = book
        } label: {
            Label(L("chat.title"), systemImage: "bubble.left.and.bubble.right")
        }
        
        if viewModel.isUserImportedBook(book) {
            Button(role: .destructive) {
                viewModel.requestDelete(book)
            } label: {
                Label(L("common.delete"), systemImage: "trash")
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return Array(repeating: GridItem(.flexible(), spacing: 28), count: 6)
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 24), count: 2)
        }
    }
}

// MARK: - 书籍卡片（Apple Books 风格）
struct BookCard: View {
    let book: Book
    var isUserImported: Bool = false
    var colors: ThemeColors = .dark
    
    private let coverAspectRatio: CGFloat = 2.0 / 3.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = width / coverAspectRatio
                
                ZStack(alignment: .topTrailing) {
                    BookCoverView(book: book, colors: colors)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    
                    if isUserImported {
                        Text(L("library.import.success"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .padding(4)
                    }
                }
            }
            .aspectRatio(coverAspectRatio, contentMode: .fit)
            
            Text(book.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(colors.primaryText)
            
            Text(book.author)
                .font(.caption)
                .foregroundColor(colors.secondaryText)
                .lineLimit(1)
        }
    }
}

#Preview {
    BookshelfView()
        .environment(BookState())
        .environment(ThemeManager.shared)
}
