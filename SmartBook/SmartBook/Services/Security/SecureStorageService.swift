// SecureStorageService.swift - 统一的安全存储服务

import Foundation

/// 安全存储服务 - 结合 Keychain 和加密功能的统一接口
class SecureStorageService {
    
    // MARK: - 单例
    
    static let shared = SecureStorageService()
    
    private init() {}
    
    // MARK: - 私有依赖
    
    private let keychain = KeychainService.shared
    private let encryption = EncryptionService.shared
    
    // MARK: - 公共方法
    
    /// 安全保存字符串（使用 Keychain）
    /// - Parameters:
    ///   - value: 要保存的值
    ///   - key: 键名
    /// - Throws: KeychainError
    func saveSecure(_ value: String, forKey key: String) throws {
        try keychain.save(value, forKey: key)
    }
    
    /// 安全读取字符串（从 Keychain）
    /// - Parameter key: 键名
    /// - Returns: 读取的字符串
    /// - Throws: KeychainError
    func readSecure(forKey key: String) throws -> String {
        return try keychain.read(forKey: key)
    }
    
    /// 保存加密字符串（使用 UserDefaults + 加密）
    /// - Parameters:
    ///   - value: 要保存的值
    ///   - key: 键名
    /// - Throws: EncryptionError
    func saveEncrypted(_ value: String, forKey key: String) throws {
        let encryptedValue = try encryption.encrypt(value)
        UserDefaults.standard.set(encryptedValue, forKey: key)
    }
    
    /// 读取加密字符串（从 UserDefaults）
    /// - Parameter key: 键名
    /// - Returns: 解密后的字符串
    /// - Throws: EncryptionError
    func readEncrypted(forKey key: String) throws -> String {
        guard let encryptedValue = UserDefaults.standard.string(forKey: key) else {
            throw EncryptionError.invalidData
        }
        return try encryption.decrypt(encryptedValue)
    }
    
    /// 保存加密对象（使用 UserDefaults + 加密）
    /// - Parameters:
    ///   - object: 可编码对象
    ///   - key: 键名
    /// - Throws: EncryptionError
    func saveEncrypted<T: Codable>(_ object: T, forKey key: String) throws {
        let encryptedString = try encryption.encrypt(object)
        UserDefaults.standard.set(encryptedString, forKey: key)
    }
    
    /// 读取加密对象（从 UserDefaults）
    /// - Parameters:
    ///   - key: 键名
    ///   - type: 对象类型
    /// - Returns: 解密后的对象
    /// - Throws: EncryptionError
    func readEncrypted<T: Codable>(forKey key: String, as type: T.Type) throws -> T {
        guard let encryptedString = UserDefaults.standard.string(forKey: key) else {
            throw EncryptionError.invalidData
        }
        return try encryption.decrypt(encryptedString, as: type)
    }
    
    /// 删除安全存储的数据
    /// - Parameter key: 键名
    func delete(forKey key: String) {
        // 尝试从 Keychain 删除
        try? keychain.delete(forKey: key)
        // 从 UserDefaults 删除
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// 清空所有安全存储
    func clearAll() {
        // 清空 Keychain
        try? keychain.clear()
        
        // 清空 UserDefaults 中的加密数据
        // 注意：这会删除所有 UserDefaults 数据，谨慎使用
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}

// MARK: - 便捷扩展

extension SecureStorageService {
    
    /// 安全保存（不抛出错误）
    @discardableResult
    func saveSecureSafe(_ value: String, forKey key: String) -> Bool {
        return (try? saveSecure(value, forKey: key)) != nil
    }
    
    /// 安全读取（不抛出错误）
    func readSecureSafe(forKey key: String) -> String? {
        return try? readSecure(forKey: key)
    }
    
    /// 保存加密字符串（不抛出错误）
    @discardableResult
    func saveEncryptedSafe(_ value: String, forKey key: String) -> Bool {
        return (try? saveEncrypted(value, forKey: key)) != nil
    }
    
    /// 读取加密字符串（不抛出错误）
    func readEncryptedSafe(forKey key: String) -> String? {
        return try? readEncrypted(forKey: key)
    }
    
    /// 保存加密对象（不抛出错误）
    @discardableResult
    func saveEncryptedSafe<T: Codable>(_ object: T, forKey key: String) -> Bool {
        return (try? saveEncrypted(object, forKey: key)) != nil
    }
    
    /// 读取加密对象（不抛出错误）
    func readEncryptedSafe<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        return try? readEncrypted(forKey: key, as: type)
    }
}

// MARK: - 常用场景扩展

extension SecureStorageService {
    
    /// 保存 API Token
    func saveAPIToken(_ token: String) throws {
        try saveSecure(token, forKey: "api_token")
    }
    
    /// 读取 API Token
    func readAPIToken() throws -> String {
        return try readSecure(forKey: "api_token")
    }
    
    /// 保存用户密码
    func savePassword(_ password: String, forUser username: String) throws {
        try saveSecure(password, forKey: "password_\(username)")
    }
    
    /// 读取用户密码
    func readPassword(forUser username: String) throws -> String {
        return try readSecure(forKey: "password_\(username)")
    }
    
    /// 保存用户会话
    func saveSession<T: Codable>(_ session: T) throws {
        try saveEncrypted(session, forKey: "user_session")
    }
    
    /// 读取用户会话
    func readSession<T: Codable>(as type: T.Type) throws -> T {
        return try readEncrypted(forKey: "user_session", as: type)
    }
    
    /// 保存敏感设置
    func saveSensitiveSetting(_ value: String, forKey key: String) throws {
        try saveEncrypted(value, forKey: "setting_\(key)")
    }
    
    /// 读取敏感设置
    func readSensitiveSetting(forKey key: String) throws -> String {
        return try readEncrypted(forKey: "setting_\(key)")
    }
}
