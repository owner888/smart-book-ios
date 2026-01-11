// ContentView.swift - 主视图（支持主题切换和多语言）

import SwiftUI
import UniformTypeIdentifiers

// Tab 枚举
enum AppTab: String, CaseIterable {
    case bookshelf = "tab.library"
    case chat = "tab.chat"
    case settings = "tab.settings"
    case search = "tab.search"
    
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
            Tab(L(AppTab.bookshelf.rawValue), systemImage: AppTab.bookshelf.icon, value: .bookshelf) {
                BookshelfView()
            }
            
            Tab(L(AppTab.chat.rawValue), systemImage: AppTab.chat.icon, value: .chat) {
                ChatView()
            }
            
            Tab(L(AppTab.settings.rawValue), systemImage: AppTab.settings.icon, value: .settings) {
                SettingsView()
            }
            
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
        .onChange(of: selectedTab) { _, newValue in
            if newValue != .search {
                previousTab = newValue
            }
        }
        .animation(.smooth(duration: 0.35), value: selectedTab)
    }
}

// MARK: - 书架视图
struct BookshelfView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
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
                        Text(L("common.loading"))
                            .foregroundColor(colors.secondaryText)
                    }
                } else if books.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(colors.secondaryText)
                        Text(L("library.empty"))
                            .font(.headline)
                            .foregroundColor(colors.secondaryText)
                        Text(L("library.empty.tip"))
                            .font(.caption)
                            .foregroundColor(colors.secondaryText.opacity(0.7))
                        
                        Button {
                            showingImporter = true
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
                } else {
                    ScrollView {
                        HStack {
                            Text(String(format: L("library.bookCount"), books.count))
                                .font(.subheadline)
                                .foregroundColor(colors.secondaryText)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        LazyVGrid(columns: gridColumns, spacing: horizontalSizeClass == .regular ? 36 : 24) {
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
                                                Label(L("reader.title"), systemImage: "book")
                                            }
                                        }
                                        
                                        Button {
                                            appState.selectedBook = book
                                        } label: {
                                            Label(L("chat.title"), systemImage: "bubble.left.and.bubble.right")
                                        }
                                        
                                        if appState.bookService.isUserImportedBook(book) {
                                            Button(role: .destructive) {
                                                bookToDelete = book
                                                showingDeleteAlert = true
                                            } label: {
                                                Label(L("common.delete"), systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 24)
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle(L("library.title"))
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
            .alert(L("library.delete.title"), isPresented: $showingDeleteAlert) {
                Button(L("common.cancel"), role: .cancel) { }
                Button(L("common.delete"), role: .destructive) {
                    if let book = bookToDelete {
                        deleteBook(book)
                    }
                }
            } message: {
                Text(L("library.delete.message"))
            }
            .alert(L("library.import.failed"), isPresented: $showingError) {
                Button(L("common.ok"), role: .cancel) { }
            } message: {
                Text(importError ?? L("error.generic"))
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
                    importError = L("library.import.failed") + ": \(error.localizedDescription)"
                    showingError = true
                }
            }
            if importedCount > 0 {
                await loadBooks()
            }
        case .failure(let error):
            importError = L("error.fileNotFound") + ": \(error.localizedDescription)"
            showingError = true
        }
    }
    
    func deleteBook(_ book: Book) {
        do {
            try appState.bookService.deleteBook(book)
            books.removeAll { $0.id == book.id }
        } catch {
            importError = L("common.error") + ": \(error.localizedDescription)"
            showingError = true
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
                    coverImage
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
            .fill(
                LinearGradient(
                    colors: [colors.inputBackground, colors.inputBackground.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 32))
                        .foregroundColor(colors.secondaryText.opacity(0.5))
                    Text(book.title)
                        .font(.caption2)
                        .foregroundColor(colors.secondaryText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }
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
