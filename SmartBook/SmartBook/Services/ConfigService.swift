// ConfigService.swift - 泛型配置服务基类

import Foundation

// MARK: - ConfigItem 协议
protocol ConfigItem: Identifiable, Codable, Equatable where ID == String {
    static var defaultItems: [Self] { get }
}

// MARK: - 响应格式结构体（移到外部避免泛型嵌套限制）
private struct StandardConfigResponse<T: Codable>: Codable {
    let data: ListData
    
    struct ListData: Codable {
        let list: [T]
    }
}

private struct SimpleListResponse<T: Codable>: Codable {
    let list: [T]
}

private struct WrappedResponse<T: Codable>: Codable {
    let data: [T]
}

// MARK: - 泛型配置服务基类
@Observable
class ConfigService<Item: ConfigItem> {
    var items: [Item]
    var currentItem: Item
    var isLoading = false
    
    // 缓存机制
    private var cacheTime: Date?
    private let cacheInterval: TimeInterval
    
    private let apiEndpoint: String
    private let defaultItemId: String?
    
    init(
        apiEndpoint: String,
        cacheInterval: TimeInterval = 300,
        defaultItemId: String? = nil
    ) {
        self.apiEndpoint = apiEndpoint
        self.cacheInterval = cacheInterval
        self.defaultItemId = defaultItemId
        
        self.items = Item.defaultItems
        
        // 设置默认当前项
        if let defaultId = defaultItemId,
           let defaultItem = Item.defaultItems.first(where: { $0.id == defaultId }) {
            self.currentItem = defaultItem
        } else {
            self.currentItem = Item.defaultItems.first!
        }
    }
    
    // MARK: - 加载配置（从API）
    func loadItems() async throws {
        // 检查缓存（如果设置了缓存间隔）
        if cacheInterval > 0,
           let cacheTime = cacheTime,
           Date().timeIntervalSince(cacheTime) < cacheInterval,
           !items.isEmpty && items != Item.defaultItems {
            return // 使用缓存
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // ✅ 使用 HTTPClient 统一请求
            let (data, httpResponse) = try await HTTPClient.shared.get(apiEndpoint)
            
            guard httpResponse.statusCode == 200 else {
                // 使用默认配置
                Logger.debug("⚠️ Failed to load from API, using default items")
                return
            }
            
            // 解析响应
            if let loadedItems = try parseResponse(data) {
                items = loadedItems
                
                // 更新缓存时间
                if cacheInterval > 0 {
                    cacheTime = Date()
                }
                
                // 更新当前项（确保仍然有效）
                if !items.contains(where: { $0.id == currentItem.id }) {
                    currentItem = items.first!
                }
                
                Logger.debug("✅ Loaded \(items.count) items from \(apiEndpoint)")
            }
        } catch {
            Logger.error("Failed to load items from \(apiEndpoint): \(error)")
            // 使用默认配置，不抛出错误
        }
    }
    
    // MARK: - 解析响应（子类可重写）
    func parseResponse(_ data: Data) throws -> [Item]? {
        // 1. 尝试标准格式 { "data": { "list": [...] } }
        if let response = try? JSONDecoder().decode(StandardConfigResponse<Item>.self, from: data) {
            return response.data.list
        }
        
        // 2. 尝试简化格式 { "list": [...] }
        if let response = try? JSONDecoder().decode(SimpleListResponse<Item>.self, from: data) {
            return response.list
        }
        
        // 3. 尝试包装格式 { "data": [...] }
        if let response = try? JSONDecoder().decode(WrappedResponse<Item>.self, from: data) {
            return response.data
        }
        
        // 4. 尝试直接解析数组 [...]
        if let items = try? JSONDecoder().decode([Item].self, from: data) {
            return items
        }
        
        return nil
    }
    
    // MARK: - 清除缓存
    func clearCache() {
        cacheTime = nil
    }
    
    // MARK: - 切换当前项
    func switchItem(_ item: Item) {
        currentItem = item
    }
    
    // MARK: - 根据ID获取项
    func getItem(id: String) -> Item? {
        items.first(where: { $0.id == id })
    }
}
