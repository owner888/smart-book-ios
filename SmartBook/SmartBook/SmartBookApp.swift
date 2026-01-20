// SmartBook iOS App - 主入口
// iOS 18+ / SwiftUI / 支持多语言 / 支持暗黑/浅色主题

import SwiftData
import SwiftUI

@main
struct SmartBookApp: App {
    // 状态管理（按功能领域拆分）
    let bookState = BookState()
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
                .environment(bookState)
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
