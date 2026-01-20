// SmartBook iOS App - 主入口
// iOS 18+ / SwiftUI / 支持多语言 / 支持暗黑/浅色主题

import SwiftData
import SwiftUI

@main
struct SmartBookApp: App {
    let appState = AppState()
    let themeManager = ThemeManager.shared
    let assistantService = AssistantService()
    let modelService = ModelService()

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

// MARK: - App State (全局状态管理)
@MainActor
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

    func loadBooks() async {
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
