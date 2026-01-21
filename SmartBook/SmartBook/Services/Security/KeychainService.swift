// KeychainService.swift - Keychain 安全存储服务

import Foundation
import Security

/// Keychain 错误
enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedData
    case unhandledError(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "项目未找到"
        case .duplicateItem:
            return "项目已存在"
        case .unexpectedData:
            return "数据格式错误"
        case .unhandledError(let status):
            return "Keychain 错误: \(status)"
        }
    }
}

/// Keychain 服务 - 用于安全存储敏感数据
class KeychainService {
    
    // MARK: - 单例
    
    static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - 公共方法
    
    /// 保存字符串到 Keychain
    /// - Parameters:
    ///   - value: 要保存的值
    ///   - key: 键名
    ///   - service: 服务名称（默认使用 Bundle Identifier）
    /// - Throws: KeychainError
    func save(_ value: String, forKey key: String, service: String? = nil) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }
        try save(data, forKey: key, service: service)
    }
    
    /// 保存数据到 Keychain
    /// - Parameters:
    ///   - data: 要保存的数据
    ///   - key: 键名
    ///   - service: 服务名称（默认使用 Bundle Identifier）
    /// - Throws: KeychainError
    func save(_ data: Data, forKey key: String, service: String? = nil) throws {
        let serviceName = service ?? defaultService
        
        // 先尝试删除已存在的项
        try? delete(forKey: key, service: service)
        
        // 创建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 添加到 Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// 从 Keychain 读取字符串
    /// - Parameters:
    ///   - key: 键名
    ///   - service: 服务名称（默认使用 Bundle Identifier）
    /// - Returns: 读取的字符串
    /// - Throws: KeychainError
    func read(forKey key: String, service: String? = nil) throws -> String {
        let data = try readData(forKey: key, service: service)
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return value
    }
    
    /// 从 Keychain 读取数据
    /// - Parameters:
    ///   - key: 键名
    ///   - service: 服务名称（默认使用 Bundle Identifier）
    /// - Returns: 读取的数据
    /// - Throws: KeychainError
    func readData(forKey key: String, service: String? = nil) throws -> Data {
        let serviceName = service ?? defaultService
        
        // 创建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // 从 Keychain 读取
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw status == errSecItemNotFound ? KeychainError.itemNotFound : KeychainError.unhandledError(status: status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }
        
        return data
    }
    
    /// 从 Keychain 删除项
    /// - Parameters:
    ///   - key: 键名
    ///   - service: 服务名称（默认使用 Bundle Identifier）
    /// - Throws: KeychainError
    func delete(forKey key: String, service: String? = nil) throws {
        let serviceName = service ?? defaultService
        
        // 创建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // 从 Keychain 删除
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// 清空所有 Keychain 项
    /// - Parameter service: 服务名称（默认使用 Bundle Identifier）
    /// - Throws: KeychainError
    func clear(service: String? = nil) throws {
        let serviceName = service ?? defaultService
        
        // 创建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        // 删除所有项
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - 私有方法
    
    /// 默认服务名称（使用 Bundle Identifier）
    private var defaultService: String {
        return Bundle.main.bundleIdentifier ?? "com.smartbook.app"
    }
}

// MARK: - 便捷扩展

extension KeychainService {
    
    /// 安全读取（不抛出错误，返回 nil）
    func readSafe(forKey key: String, service: String? = nil) -> String? {
        return try? read(forKey: key, service: service)
    }
    
    /// 安全保存（不抛出错误，返回成功状态）
    @discardableResult
    func saveSafe(_ value: String, forKey key: String, service: String? = nil) -> Bool {
        return (try? save(value, forKey: key, service: service)) != nil
    }
    
    /// 检查项是否存在
    func exists(forKey key: String, service: String? = nil) -> Bool {
        return (try? readData(forKey: key, service: service)) != nil
    }
}
