// DIContainer.swift - 依赖注入容器
// 提供统一的依赖管理，方便测试和维护

import Foundation
import SwiftData
import SwiftUI

/// 依赖注入容器
/// 负责创建和管理应用中的所有服务实例
class DIContainer {

    // MARK: - 单例

    static let shared = DIContainer()

    private init() {
        Logger.info("🏭 依赖注入容器已初始化")
    }

    // MARK: - 服务实例

    let themeManager = ThemeManager.shared
    let assistantService = AssistantService.shared
    let modelService = ModelService.shared
    let bookState = BookState()
    let bookService = BookService()
    let ttsService = TTSService()
    let checkInService = CheckInService()
    let summarizationService = SummarizationService(threshold: 20)

    /// 共享的 ChatHistoryService（延迟初始化，需要 ModelContext）
    private var _chatHistoryService: ChatHistoryService?

    /// 共享的 ChatViewModel（避免 SwiftUI 视图重建导致 deinit）
    private lazy var _chatViewModel: ChatViewModel = {
        let ttsStreamService = TTSStreamService()
        let ttsCoordinator = TTSCoordinatorService(
            nativeTTS: ttsService,
            streamTTS: ttsStreamService,
            provider: AppConfig.DefaultValues.ttsProvider
        )
        return ChatViewModel(
            streamingService: StreamingChatService(),
            ttsCoordinator: ttsCoordinator,
            ttsStreamService: ttsStreamService,
            mediaService: MediaProcessingService()
        )
    }()

    var chatViewModel: ChatViewModel { _chatViewModel }

    /// 获取或创建共享的 ChatHistoryService（需要 ModelContext，首次调用时初始化）
    func chatHistoryService(modelContext: ModelContext) -> ChatHistoryService {
        if let existing = _chatHistoryService {
            return existing
        }
        let service = ChatHistoryService(modelContext: modelContext)
        _chatHistoryService = service
        return service
    }

}

// MARK: - SwiftUI Environment Extension

/// 为方便在 SwiftUI 中使用，提供 Environment 扩展
extension EnvironmentValues {
    @Entry var diContainer: DIContainer = .shared
}

