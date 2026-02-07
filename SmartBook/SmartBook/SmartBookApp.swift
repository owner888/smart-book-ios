// SmartBook iOS App - 主入口
// iOS 18+ / SwiftUI / 支持多语言 / 支持暗黑/浅色主题

import SwiftData
import SwiftUI

@main
struct SmartBookApp: App {
    // ✅ 使用依赖注入容器统一管理所有服务
    private let container = DIContainer.shared

    init() {
        // 在 Debug 模式下打印配置信息
        #if DEBUG
            DebugConfig.printAllConfiguration()
        #endif
        
        // 启动时加载模型列表和助手列表
        Task {
            await MenuConfig.loadAIModels()
            await MenuConfig.loadAssistants()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.diContainer, container)
                .environment(container.themeManager)
                .environment(container.modelService)
                .environment(container.assistantService)
                .environment(container.bookState)
                .environment(container.makeBookService())
                .environmentObject(container.makeTTSService())
                .environment(container.makeCheckInService())
                .preferredColorScheme(container.themeManager.colorScheme)
        }
        .modelContainer(
            for: [
                Conversation.self,
                Message.self,
            ]
        )
    }
}
