// AppConfig.swift - 应用配置管理
// 统一管理应用的配置信息

import Foundation

/// 应用配置管理器
enum AppConfig {

    // MARK: - API 配置（从 Info.plist / Secrets.xcconfig 读取）

    /// API 基础 URL（HTTP/HTTPS）
    /// 优先级：UserDefaults（设置页面修改）> Info.plist (Secrets.xcconfig) > 硬编码默认值
    static var apiBaseURL: String {
        UserDefaults.standard.string(forKey: Keys.apiBaseURL) ?? defaultAPIBaseURL
    }

    /// 默认 API URL（从 Info.plist 读取或使用硬编码默认值）
    /// 用于 @AppStorage 的初始值和回退值
    static var defaultAPIBaseURL: String {
        Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? DefaultValues.apiBaseURL
    }

    /// WebSocket ASR URL（语音识别）
    static var apiASRURL: String {
        Bundle.main.infoDictionary?["API_ASR_URL"] as? String ?? DefaultValues.apiASRURL
    }

    /// WebSocket TTS URL（语音合成）
    static var apiTTSURL: String {
        Bundle.main.infoDictionary?["API_TTS_URL"] as? String ?? DefaultValues.apiTTSURL
    }

    /// API Key
    /// 从 Info.plist 读取（Secrets.xcconfig）
    static var apiKey: String {
        Bundle.main.infoDictionary?["API_KEY"] as? String ?? ""
    }

    // MARK: - UserDefaults Keys

    enum Keys {
        static let apiBaseURL = "apiBaseURL"
        static let autoTTS = "autoTTS"
        static let ttsRate = "ttsRate"
        static let selectedVoice = "selectedVoice"
        static let asrProvider = "asrProvider"
        static let asrLanguage = "asrLanguage"
        static let ttsProvider = "ttsProvider"  // TTS 提供商
        static let enableGoogleSearch = "enableGoogleSearch"  // Google Search 开关
        static let enableMCPTools = "enableMCPTools"  // MCP 工具开关
    }

    // MARK: - 默认值

    enum DefaultValues {
        static let apiBaseURL = "http://localhost:9527"
        static let apiASRURL = "ws://localhost:9525"
        static let apiTTSURL = "ws://localhost:9524"
        static let autoTTS = true
        static let ttsRate = 1.0
        static let asrProvider = "deepgram"  // native, google, deepgram
        static let asrLanguage = "zh-CN"  // 默认中文
        static let ttsProvider = "google"  // native（系统语音）, google（Google TTS）
        static let defaultModel = "gemini-2.5-flash"  // 默认 AI 模型（支持 thinking）
        static let enableGoogleSearch = false  // 默认关闭（与 MCP 冲突）
        static let enableMCPTools = true  // 默认开启 MCP 工具
    }
}
