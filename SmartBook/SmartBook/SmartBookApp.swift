// SmartBook iOS App - 主入口
// iOS 18+ / SwiftUI / 支持多语言 / 支持暗黑/浅色主题

import SwiftUI

@main
struct SmartBookApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

// MARK: - App State (全局状态管理)
@Observable
class AppState {
    var selectedBook: Book?
    var books: [Book] = []
    var isLoading = false
    var errorMessage: String?
    
    // 服务实例
    let chatService = ChatService()
    let bookService = BookService()
    let speechService = SpeechService()
    let ttsService = TTSService()
    let checkInService = CheckInService()
    
    // API 配置 - 从 Info.plist 读取
    static let apiBaseURL: String = {
        Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? "http://localhost:8080"
    }()
    
    init() {
        Task {
            await loadBooks()
        }
    }
    
    @MainActor
    func loadBooks() async {
        isLoading = true
        do {
            books = try await bookService.fetchBooks()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
