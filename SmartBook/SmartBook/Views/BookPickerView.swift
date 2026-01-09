// BookPickerView.swift - 书籍选择器视图

import SwiftUI

struct BookPickerView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var books: [Book] = []
    @State private var isLoading = true
    @State private var searchText = ""
    var colors: ThemeColors
    let onSelect: (Book) -> Void
    
    private var themeColors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeColors.background.ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(themeColors.primaryText)
                        Text("加载书籍...")
                            .foregroundColor(themeColors.secondaryText)
                    }
                } else if books.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 50))
                            .foregroundColor(themeColors.secondaryText)
                        Text("暂无书籍")
                            .foregroundColor(themeColors.secondaryText)
                        Text("请先在书架中导入书籍")
                            .font(.caption)
                            .foregroundColor(themeColors.secondaryText.opacity(0.7))
                    }
                } else {
                    List {
                        ForEach(filteredBooks) { book in
                            BookPickerRow(book: book, colors: themeColors, isSelected: appState.selectedBook?.id == book.id)
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
            .navigationTitle("选择书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(themeColors.navigationBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, prompt: "搜索书籍")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(themeColors.primaryText)
                }
            }
        }
        .task {
            await loadBooks()
        }
    }
    
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

// MARK: - 书籍选择行
struct BookPickerRow: View {
    let book: Book
    var colors: ThemeColors
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面缩略图
            bookCover
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // 书籍信息
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
            
            // 选中标识
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
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
}

#Preview {
    BookPickerView(colors: .dark) { book in
        print("Selected: \(book.title)")
    }
    .environment(AppState())
    .environment(ThemeManager.shared)
}
