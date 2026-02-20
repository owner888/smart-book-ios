// EncryptionService.swift - 数据加密/解密服务

import CryptoKit
import Foundation

/// 加密错误
enum EncryptionError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case invalidData
    case keyGenerationFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "加密失败"
        case .decryptionFailed:
            return "解密失败"
        case .invalidKey:
            return "无效的加密密钥"
        case .invalidData:
            return "无效的数据"
        case .keyGenerationFailed:
            return "密钥生成失败"
        }
    }
}

/// 加密服务 - 使用 AES-GCM 进行数据加密
class EncryptionService {

    // MARK: - 单例

    static let shared = EncryptionService()

    private init() {
        // 初始化时生成或加载加密密钥
        if encryptionKey == nil {
            encryptionKey = try? generateOrLoadEncryptionKey()
        }
    }

    // MARK: - 私有属性

    /// 加密密钥（存储在 Keychain 中）
    private var encryptionKey: SymmetricKey?

    /// Keychain 中密钥的键名
    private let encryptionKeyName = "com.smartbook.encryption.key"

    // MARK: - 公共方法

    /// 加密字符串
    /// - Parameter plainText: 明文字符串
    /// - Returns: 加密后的 Base64 字符串
    /// - Throws: EncryptionError
    func encrypt(_ plainText: String) throws -> String {
        guard let data = plainText.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }

        let encryptedData = try encrypt(data)
        return encryptedData.base64EncodedString()
    }

    /// 加密数据
    /// - Parameter data: 原始数据
    /// - Returns: 加密后的数据
    /// - Throws: EncryptionError
    func encrypt(_ data: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw EncryptionError.invalidKey
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            return combined
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    /// 解密字符串
    /// - Parameter encryptedText: 加密的 Base64 字符串
    /// - Returns: 解密后的明文字符串
    /// - Throws: EncryptionError
    func decrypt(_ encryptedText: String) throws -> String {
        guard let data = Data(base64Encoded: encryptedText) else {
            throw EncryptionError.invalidData
        }

        let decryptedData = try decrypt(data)
        guard let plainText = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }

        return plainText
    }

    /// 解密数据
    /// - Parameter encryptedData: 加密的数据
    /// - Returns: 解密后的原始数据
    /// - Throws: EncryptionError
    func decrypt(_ encryptedData: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw EncryptionError.invalidKey
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    /// 重置加密密钥（生成新密钥）
    /// - Throws: EncryptionError
    func resetEncryptionKey() throws {
        // 删除旧密钥
        try? KeychainService.shared.delete(forKey: encryptionKeyName)

        // 生成新密钥
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        // 保存到 Keychain
        try KeychainService.shared.save(keyData, forKey: encryptionKeyName)

        // 更新内存中的密钥
        encryptionKey = newKey
    }

    // MARK: - 私有方法

    /// 生成或加载加密密钥
    /// - Returns: 对称密钥
    /// - Throws: EncryptionError
    private func generateOrLoadEncryptionKey() throws -> SymmetricKey {
        // 尝试从 Keychain 加载密钥
        if let keyData = try? KeychainService.shared.readData(forKey: encryptionKeyName) {
            return SymmetricKey(data: keyData)
        }

        // 生成新密钥
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        // 保存到 Keychain
        do {
            try KeychainService.shared.save(keyData, forKey: encryptionKeyName)
        } catch {
            throw EncryptionError.keyGenerationFailed
        }

        return newKey
    }
}

// MARK: - 便捷扩展

extension EncryptionService {

    /// 安全加密（不抛出错误，返回 nil）
    func encryptSafe(_ plainText: String) -> String? {
        return try? encrypt(plainText)
    }

    /// 安全解密（不抛出错误，返回 nil）
    func decryptSafe(_ encryptedText: String) -> String? {
        return try? decrypt(encryptedText)
    }

    /// 加密 Codable 对象
    /// - Parameter object: 可编码对象
    /// - Returns: 加密后的 Base64 字符串
    /// - Throws: EncryptionError
    func encrypt<T: Codable>(_ object: T) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        let encryptedData = try encrypt(data)
        return encryptedData.base64EncodedString()
    }

    /// 解密为 Codable 对象
    /// - Parameter encryptedText: 加密的 Base64 字符串
    /// - Returns: 解密后的对象
    /// - Throws: EncryptionError
    func decrypt<T: Codable>(_ encryptedText: String, as type: T.Type) throws -> T {
        guard let data = Data(base64Encoded: encryptedText) else {
            throw EncryptionError.invalidData
        }

        let decryptedData = try decrypt(data)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: decryptedData)
    }
}

// MARK: - 哈希工具

extension EncryptionService {

    /// 生成 SHA256 哈希
    /// - Parameter string: 输入字符串
    /// - Returns: SHA256 哈希（十六进制字符串）
    func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 生成 MD5 哈希（用于兼容性，不推荐用于安全场景）
    /// - Parameter string: 输入字符串
    /// - Returns: MD5 哈希（十六进制字符串）
    func md5(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        let hash = Insecure.MD5.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
