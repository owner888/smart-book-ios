// ModelService.swift - AI 模型管理服务

import Foundation

@Observable
class ModelService {
    static let shared = ModelService()  // 单例
    
    var models: [AIModel]
    var currentModel: AIModel
    var isLoading = false
    
    // 缓存机制
    private var cacheTime: Date?
    private let cacheInterval: TimeInterval = 300  // 5分钟缓存

    private init() {  // private 防止外部创建实例
        self.models = AIModel.defaultModels
        self.currentModel = AIModel.defaultModels.first!
    }

    // 加载模型列表（从API）
    func loadModels() async throws {
        // 检查缓存
        if let cacheTime = cacheTime,
           Date().timeIntervalSince(cacheTime) < cacheInterval,
           !models.isEmpty && models != AIModel.defaultModels {
            return  // 使用缓存
        }
        
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: "\(AppConfig.apiBaseURL)/api/models")!

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // 使用默认模型
                return
            }

            // 支持 ResponseMiddleware 包装的格式
            struct ModelsResponse: Codable {
                let success: Bool
                let data: ModelsData
                
                struct ModelsData: Codable {
                    let models: [AIModel]
                }
            }
            
            // 尝试解析包装格式
            if let response = try? JSONDecoder().decode(ModelsResponse.self, from: data) {
                models = response.data.models
                cacheTime = Date()
            }
            // 尝试直接解析数组
            else if let loadedModels = try? JSONDecoder().decode([AIModel].self, from: data),
               !loadedModels.isEmpty {
                models = loadedModels
                cacheTime = Date()
            }
            
            // 确保 currentModel 有效
            if !models.contains(where: { $0.id == currentModel.id }) {
                currentModel = models.first!
            }
        } catch {
            // 使用默认模型，不抛出错误
            Logger.error("Failed to load models: \(error)")
        }
    }
    
    // 清除缓存
    func clearCache() {
        cacheTime = nil
    }
    
    // 切换模型
    func switchModel(_ model: AIModel) {
        currentModel = model
    }
    
    // 根据ID获取模型
    func getModel(id: String) -> AIModel? {
        models.first(where: { $0.id == id })
    }
}
