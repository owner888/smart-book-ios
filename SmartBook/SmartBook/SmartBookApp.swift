// SmartBook iOS App - 主入口
// iOS 18+ / SwiftUI / 支持多语言 / 支持暗黑/浅色主题

import SwiftUI

@main
struct SmartBookApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager.shared
    @State private var assistantService = AssistantService()
    @State private var modelService = ModelService()
    
    init() {
        // 在 Debug 模式下打印配置信息
        #if DEBUG
        DebugConfig.printAllConfiguration()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(themeManager)
                .environment(assistantService)
                .environment(modelService)
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
