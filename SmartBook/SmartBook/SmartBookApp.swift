// SmartBook iOS App - 主入口
// iOS 18+ / SwiftUI / 支持多语言 / 支持暗黑/浅色主题

import SwiftData
import SwiftUI

@main
struct SmartBookApp: App {
    // 状态管理
    let appState = AppState()
    let themeManager = ThemeManager.shared
    
    // AI 服务
    let assistantService = AssistantService()
    let modelService = ModelService()
    
    // 业务服务
    let bookService = BookService()
    let speechService = SpeechService()
    let ttsService = TTSService()
    let checkInService = CheckInService()

    init() {
        // 在 Debug 模式下打印配置信息
        #if DEBUG
            DebugConfig.printAllConfiguration()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .environment(modelService)
                .environment(assistantService)
                .environment(appState)
                .environment(bookService)
                .environment(speechService)
                .environment(ttsService)
                .environment(checkInService)
                .preferredColorScheme(themeManager.colorScheme)
        }
        .modelContainer(
            for: [
                ConversationModel.self,
                MessageModel.self,
            ]
        )
    }
}

// MARK: - App State (全局状态管理 - 只负责状态，不持有服务)
@MainActor
@Observable
class AppState {
    // 状态数据
    var selectedBook: Book?
    var books: [Book] = []
    var isLoading = false
    var errorMessage: String?

    // 加载书籍（需要注入 bookService）
    func loadBooks(using bookService: BookService) async {
        isLoading = true
        errorMessage = nil
        do {
            books = try await bookService.fetchBooks()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
