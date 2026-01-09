// ContentView.swift - 主视图（Liquid Glass 风格）

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 书架
            BookshelfView()
                .tabItem {
                    Label("书架", systemImage: "books.vertical")
                }
                .tag(0)
            
            // AI 对话
            ChatView()
                .tabItem {
                    Label("对话", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(1)
            
            // 设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(.white)
    }
}

// MARK: - 书架视图
struct BookshelfView: View {
    @Environment(AppState.self) var appState
    @State private var books: [Book] = []
    @State private var searchText = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    // 加载中状态
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("正在加载书籍...")
                            .foregroundColor(.gray)
                    }
                } else if books.isEmpty {
                    // 空状态
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("暂无书籍")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("请在 Resources/Books 目录添加 epub 文件")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        // 书籍数量统计
                        HStack {
                            Text("共 \(filteredBooks.count) 本书")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(filteredBooks) { book in
                                BookCard(book: book)
                                    .onTapGesture {
                                        appState.selectedBook = book
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("书架")
            .searchable(text: $searchText, prompt: "搜索书籍")
            .task {
                await loadBooks()
            }
            .refreshable {
                await loadBooks()
            }
        }
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
    
    func loadBooks() async {
        isLoading = true
        do {
            books = try await appState.bookService.fetchBooks()
        } catch {
            appState.errorMessage = error.localizedDescription
            // 如果 API 失败，尝试直接加载本地书籍
            books = appState.bookService.loadLocalBooks()
        }
        isLoading = false
    }
}

// MARK: - 书籍卡片（Liquid Glass 风格）
struct BookCard: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面
            AsyncImage(url: URL(string: book.coverURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 标题
            Text(book.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.white)
            
            // 作者
            Text(book.author)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background {
            // Liquid Glass 效果
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
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
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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
}
