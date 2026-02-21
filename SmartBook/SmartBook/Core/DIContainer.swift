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

    // MARK: - 单例服务（全局共享）

    private lazy var _themeManager: ThemeManager = {
        ThemeManager.shared
    }()

    private lazy var _assistantService: AssistantService = {
        AssistantService.shared
    }()

    private lazy var _modelService: ModelService = {
        ModelService.shared
    }()

    // MARK: - 状态管理

    private lazy var _bookState: BookState = {
        BookState()
    }()

    // MARK: - 单例服务（全局共享，避免 SwiftUI 重建视图）

    private lazy var _bookService: BookService = {
        BookService()
    }()

    private lazy var _ttsService: TTSService = {
        TTSService()
    }()

    private lazy var _checkInService: CheckInService = {
        CheckInService()
    }()

    /// 共享的 SummarizationService
    private lazy var _summarizationService: SummarizationService = {
        SummarizationService(threshold: 3)
    }()

    /// 共享的 ChatHistoryService（延迟初始化，需要 ModelContext）
    private var _chatHistoryService: ChatHistoryService?

    /// 共享的 ChatViewModel（避免 SwiftUI 视图重建导致 deinit）
    private lazy var _chatViewModel: ChatViewModel = {
        let ttsStreamService = TTSStreamService()
        let ttsCoordinator = TTSCoordinatorService(
            nativeTTS: _ttsService,
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

    // MARK: - 服务访问方法

    var bookService: BookService { _bookService }
    var ttsService: TTSService { _ttsService }
    var checkInService: CheckInService { _checkInService }
    var summarizationService: SummarizationService { _summarizationService }
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

    // MARK: - 访问单例服务

    var themeManager: ThemeManager {
        _themeManager
    }

    var assistantService: AssistantService {
        _assistantService
    }

    var modelService: ModelService {
        _modelService
    }

    var bookState: BookState {
        _bookState
    }
}

// MARK: - SwiftUI Environment Extension

/// 为方便在 SwiftUI 中使用，提供 Environment 扩展
extension EnvironmentValues {
    @Entry var diContainer: DIContainer = .shared
}

