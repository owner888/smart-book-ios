// ModelService.swift - AI 模型管理服务

import Foundation

@Observable
class ModelService: ConfigService<AIModel> {
    static let shared = ModelService()  // 单例

    private init() {
        super.init(
            apiEndpoint: "/api/config/models",
            cacheInterval: 300,  // 5分钟缓存
            defaultItemId: nil
        )
    }

    // MARK: - 便捷访问属性
    var models: [AIModel] {
        get { items }
        set { items = newValue }
    }

    var currentModel: AIModel {
        get { currentItem }
        set { currentItem = newValue }
    }

    // MARK: - 加载模型列表（从API）
    func loadModels() async throws {
        try await loadItems()
    }

    // MARK: - 切换模型
    func switchModel(_ model: AIModel) {
        switchItem(model)
    }

    // MARK: - 根据ID获取模型
    func getModel(id: String) -> AIModel? {
        getItem(id: id)
    }

    // MARK: - 重写解析方法以支持额外的 default 字段
    override func parseResponse(_ data: Data) throws -> [AIModel]? {
        // 尝试解析带有 default 字段的响应
        struct ModelsResponse: Codable {
            let data: ModelsData

            struct ModelsData: Codable {
                let list: [AIModel]
                let `default`: String?
                let source: String?
            }
        }

        if let response = try? JSONDecoder().decode(ModelsResponse.self, from: data) {
            // 使用 API 返回的 default 字段设置默认模型
            if let defaultModelId = response.data.default,
                let defaultModel = response.data.list.first(where: { $0.id == defaultModelId })
            {
                currentModel = defaultModel
                Logger.debug("✅ Set default model from API: \(defaultModelId)")
            }
            return response.data.list
        }

        // 回退到基类的解析方法
        return try super.parseResponse(data)
    }
}
