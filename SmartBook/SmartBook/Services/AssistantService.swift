// AssistantService.swift - 助手配置服务

import Foundation

@Observable
class AssistantService: ConfigService<Assistant> {
    static let shared = AssistantService()

    private init() {
        super.init(
            apiEndpoint: "/api/config/assistants",
            cacheInterval: 0,  // 不缓存，每次都从服务器加载最新配置
            defaultItemId: "chat"  // 默认选中通用聊天
        )
    }

    // MARK: - 便捷访问属性
    var assistants: [Assistant] {
        get { items }
        set { items = newValue }
    }
    
    var currentAssistant: Assistant {
        get { currentItem }
        set { currentItem = newValue }
    }

    // MARK: - 加载助手配置（从API）
    func loadAssistants() async throws {
        try await loadItems()
    }

    // MARK: - 切换助手
    func switchAssistant(_ assistant: Assistant) {
        switchItem(assistant)
    }

    // MARK: - 根据ID获取助手
    func getAssistant(id: String) -> Assistant? {
        getItem(id: id)
    }
    
    // MARK: - 重写解析方法以支持额外的 default 字段
    override func parseResponse(_ data: Data) throws -> [Assistant]? {
        // 尝试解析带有 default 字段的响应
        struct AssistantsResponse: Codable {
            let data: AssistantsData
            
            struct AssistantsData: Codable {
                let list: [Assistant]
                let `default`: String?
            }
        }
        
        if let response = try? JSONDecoder().decode(AssistantsResponse.self, from: data) {
            // 使用 API 返回的 default 字段设置默认助手
            if let defaultAssistantId = response.data.default,
               let defaultAssistant = response.data.list.first(where: { $0.id == defaultAssistantId }) {
                currentAssistant = defaultAssistant
                Logger.debug("✅ Set default assistant from API: \(defaultAssistantId)")
            }
            return response.data.list
        }
        
        // 回退到基类的解析方法
        return try super.parseResponse(data)
    }
}
