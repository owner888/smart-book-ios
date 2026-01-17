// AppConfig.swift - 应用配置管理
// 统一管理应用的配置信息

import Foundation

/// 应用配置管理器
enum AppConfig {
    
    // MARK: - API 配置
    
    /// API 基础 URL
    /// 优先级：用户设置 > Info.plist (Secrets.xcconfig) > 默认值
    static var apiBaseURL: String {
        // 1. 优先使用用户在设置中配置的 URL
        if let userURL = UserDefaults.standard.string(forKey: Keys.apiBaseURL), !userURL.isEmpty {
            return userURL
        }
        
        // 2. 其次使用 Info.plist 中配置的 URL（来自 Secrets.xcconfig）
        if let configURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String, !configURL.isEmpty {
            return configURL
        }
        
        // 3. 最后使用默认值
        return DefaultValues.apiBaseURL
    }
    
    /// 获取配置的初始 URL（用于 @AppStorage 初始化）
    static var initialAPIBaseURL: String {
        Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? DefaultValues.apiBaseURL
    }
    
    // MARK: - UserDefaults Keys
    
    enum Keys {
        static let apiBaseURL = "apiBaseURL"
        static let autoTTS = "autoTTS"
        static let ttsRate = "ttsRate"
        static let selectedVoice = "selectedVoice"
    }
    
    // MARK: - 默认值
    
    enum DefaultValues {
        static let apiBaseURL = "http://localhost:8080"
        static let autoTTS = true
        static let ttsRate = 1.0
    }
}
