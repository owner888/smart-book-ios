// SmartBook iOS App - 主入口
// iOS 18+ / SwiftUI / 支持暗黑/浅色主题

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
    var isLoading = false
    var errorMessage: String?
    
    // 服务实例
    let chatService = ChatService()
    let bookService = BookService()
    let speechService = SpeechService()
    let ttsService = TTSService()
    
    // API 配置
    static let apiBaseURL = "http://localhost:8080"  // 你的 PHP 后端地址
}
