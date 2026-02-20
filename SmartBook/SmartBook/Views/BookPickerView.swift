// BookPickerView.swift - 书籍选择器视图（支持多语言）

import SwiftUI

struct BookPickerView: View {
    @Environment(BookState.self) var bookState
    @Environment(ThemeManager.self) var themeManager
    @Environment(BookService.self) var bookService
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedBookId: String?
    @State private var viewMode: ViewMode = .grid
    var colors: ThemeColors
    let onSelect: (Book) -> Void

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var themeColors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }

    enum ViewMode {
        case grid, list
    }

    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return bookState.books
        }
        return bookState.books.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        if isPad {
            iPadFilePickerStyle
        } else {
            iPhoneListStyle
        }
    }

    // MARK: - iPad 文件选择器风格
    private var iPadFilePickerStyle: some View {
        NavigationSplitView {
            // 左侧边栏
            List {
                Section {
                    NavigationLink {
                        EmptyView()
                    } label: {
                        Label("Recents", systemImage: "clock")
                    }

                    NavigationLink {
                        EmptyView()
                    } label: {
                        Label("Shared", systemImage: "person.2")
                    }
                }

                Section("Favorites") {
                    NavigationLink {
                        EmptyView()
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                }

                Section("Locations") {
                    NavigationLink {
                        EmptyView()
                    } label: {
                        Label("iCloud Drive", systemImage: "icloud")
                    }

                    NavigationLink {
                        EmptyView()
                    } label: {
                        Label("On My iPad", systemImage: "ipad")
                    }
                }

                Section("Tags") {
                    NavigationLink {
                        EmptyView()
                    } label: {
                        HStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 12, height: 12)
                            Text("Red")
                        }
                    }
                }
            }
            .navigationTitle("Books")
            .listStyle(.sidebar)
            .frame(minWidth: 250, idealWidth: 280)
        } detail: {
            // 右侧主内容区
            NavigationStack {
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()

                    if bookState.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(L("library.loadingBooks"))
                                .foregroundColor(.secondary)
                        }
                    } else if filteredBooks.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "books.vertical")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text(bookState.books.isEmpty ? L("picker.noBooks") : "No results")
                                .foregroundColor(.secondary)
                            if bookState.books.isEmpty {
                                Text(L("picker.importFirst"))
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                    } else {
                        ScrollView {
                            if viewMode == .grid {
                                gridView
                            } else {
                                listView
                            }
                        }
                    }
                }
                .navigationTitle("Books")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 0) {
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(Color(UIColor.systemGray5))
                                    )
                            }

                            Spacer().frame(width: 12)

                            Button(action: {}) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(Color(UIColor.systemGray5))
                                    )
                            }
                        }
                    }

                    ToolbarItem(placement: .principal) {
                        Menu {
                            Text("Books")
                        } label: {
                            HStack(spacing: 4) {
                                Text("Books")
                                    .font(.headline)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.primary)
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation {
                                    viewMode = viewMode == .grid ? .list : .grid
                                }
                            }) {
                                Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                                    .font(.system(size: 16))
                            }

                            Button(action: {}) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16))
                            }

                            Button(action: {
                                if let book = bookState.books.first(where: { $0.id == selectedBookId }) {
                                    onSelect(book)
                                    dismiss()
                                }
                            }) {
                                Text("Open")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedBookId == nil ? Color.gray : Color.blue)
                                    )
                            }
                            .disabled(selectedBookId == nil)
                        }
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await loadBooks()
        }
    }

    // MARK: - 网格视图
    private var gridView: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 20)
            ],
            spacing: 20
        ) {
            ForEach(filteredBooks) { book in
                FileGridItem(
                    book: book,
                    isSelected: selectedBookId == book.id,
                    colors: themeColors
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedBookId = book.id
                    }
                }
                .onTapGesture(count: 2) {
                    onSelect(book)
                    dismiss()
                }
            }
        }
        .padding()
    }

    // MARK: - 列表视图
    private var listView: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredBooks) { book in
                FileListItem(
                    book: book,
                    isSelected: selectedBookId == book.id,
                    colors: themeColors
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedBookId = book.id
                    }
                }
                .onTapGesture(count: 2) {
                    onSelect(book)
                    dismiss()
                }

                if book.id != filteredBooks.last?.id {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - iPhone 列表风格（保持原样）
    private var iPhoneListStyle: some View {
        NavigationStack {
            ZStack {
                themeColors.background.ignoresSafeArea()

                if bookState.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(themeColors.primaryText)
                        Text(L("library.loadingBooks"))
                            .foregroundColor(themeColors.secondaryText)
                    }
                } else if bookState.books.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 50))
                            .foregroundColor(themeColors.secondaryText)
                        Text(L("picker.noBooks"))
                            .foregroundColor(themeColors.secondaryText)
                        Text(L("picker.importFirst"))
                            .font(.caption)
                            .foregroundColor(themeColors.secondaryText.opacity(0.7))
                    }
                } else {
                    List {
                        ForEach(filteredBooks) { book in
                            BookPickerRow(
                                book: book,
                                colors: themeColors,
                                isSelected: bookState.selectedBook?.id == book.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(book)
                            }
                            .listRowBackground(themeColors.cardBackground)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(L("picker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(themeColors.navigationBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, prompt: L("library.searchBooks"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(themeColors.primaryText)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                .allowsHitTesting(false)
        )
        .task {
            await loadBooks()
        }
    }

    func loadBooks() async {
        await bookState.loadBooks(using: bookService)
    }
}

// MARK: - 文件网格项（类似 iOS 文件 App）
struct FileGridItem: View {
    let book: Book
    let isSelected: Bool
    var colors: ThemeColors

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(height: 140)

                BookCoverView(book: book, colors: colors)
                    .frame(width: 80, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )

            Text(book.title)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
        }
        .frame(width: 120)
    }
}

// MARK: - 文件列表项（类似 iOS 文件 App）
struct FileListItem: View {
    let book: Book
    let isSelected: Bool
    var colors: ThemeColors

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(book: book, colors: colors)
                .frame(width: 40, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(book.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

struct BookPickerRow: View {
    let book: Book
    var colors: ThemeColors
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(book: book, colors: colors)
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .foregroundColor(colors.primaryText)
                    .lineLimit(2)

                Text(book.author)
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BookPickerView(colors: .dark) { book in
        Logger.info("Selected: \(book.title)")
    }
    .environment(BookState())
    .environment(ThemeManager.shared)
}
