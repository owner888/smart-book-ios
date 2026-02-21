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

    /// 共享的 ChatViewModel（避免 SwiftUI 视图重建导致 deinit）
    private lazy var _chatViewModel: ChatViewModel = {
        let streamingService = makeStreamingChatService()
        let ttsCoordinator = makeTTSCoordinatorService(provider: AppConfig.DefaultValues.ttsProvider)
        let ttsStreamService = makeTTSStreamService()
        let mediaService = makeMediaProcessingService()

        return ChatViewModel(
            streamingService: streamingService,
            ttsCoordinator: ttsCoordinator,
            ttsStreamService: ttsStreamService,
            mediaService: mediaService
        )
    }()

    // MARK: - 业务服务工厂方法

    /// 获取共享的 BookService 实例
    func makeBookService() -> BookService {
        _bookService
    }

    /// 获取共享的 TTSService 实例
    func makeTTSService() -> TTSService {
        _ttsService
    }

    /// 获取共享的 CheckInService 实例
    func makeCheckInService() -> CheckInService {
        _checkInService
    }

    /// 创建 StreamingChatService 实例
    func makeStreamingChatService() -> StreamingChatService {
        StreamingChatService()
    }

    /// 创建 TTSStreamService 实例
    func makeTTSStreamService() -> TTSStreamService {
        TTSStreamService()
    }

    /// 创建 ASRService 实例
    func makeASRService() -> ASRService {
        ASRService()
    }

    /// 创建 ChatHistoryService 实例
    func makeChatHistoryService(modelContext: ModelContext) -> ChatHistoryService {
        ChatHistoryService(modelContext: modelContext)
    }

    /// 创建 SummarizationService 实例
    func makeSummarizationService(threshold: Int = 3) -> SummarizationService {
        SummarizationService(threshold: threshold)
    }

    /// 创建 MediaProcessingService 实例
    func makeMediaProcessingService() -> MediaProcessingService {
        MediaProcessingService()
    }

    /// 创建 TTSCoordinatorService 实例
    func makeTTSCoordinatorService(provider: String) -> TTSCoordinatorService {
        let nativeTTS = makeTTSService()
        let streamTTS = makeTTSStreamService()
        return TTSCoordinatorService(nativeTTS: nativeTTS, streamTTS: streamTTS, provider: provider)
    }

    // MARK: - ViewModel 工厂方法

    /// 获取共享的 ChatViewModel 实例（单例，避免 WebSocket 断开）
    func makeChatViewModel() -> ChatViewModel {
        _chatViewModel
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

// MARK: - 测试支持

#if DEBUG
    /// 测试专用的依赖注入容器
    /// 可以注入 Mock 服务用于单元测试
    class TestDIContainer: DIContainer {
        var mockBookService: BookService?
        var mockChatService: StreamingChatService?

        override func makeBookService() -> BookService {
            mockBookService ?? super.makeBookService()
        }

        override func makeStreamingChatService() -> StreamingChatService {
            mockChatService ?? super.makeStreamingChatService()
        }
    }
#endif
