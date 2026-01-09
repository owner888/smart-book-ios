// SmartBook iOS App - 主入口
// iOS 18+ / SwiftUI / Liquid Glass Design

import SwiftUI

@main
struct SmartBookApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State (全局状态管理)
@MainActor
class AppState: ObservableObject {
    @Published var selectedBook: Book?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 服务实例
    let chatService = ChatService()
    let bookService = BookService()
    let speechService = SpeechService()
    let ttsService = TTSService()
    
    // API 配置
    static let apiBaseURL = "http://localhost:8080"  // 你的 PHP 后端地址
}
