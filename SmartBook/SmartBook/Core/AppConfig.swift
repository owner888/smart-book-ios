// AppConfig.swift - 应用配置管理
// 统一管理应用的配置信息

import Foundation

/// 应用配置管理器
enum AppConfig {
    
    // MARK: - 基础配置（从 Info.plist / Secrets.xcconfig 读取）
    
    /// 是否启用 SSL（true = https/wss，false = http/ws）
    static var apiSSL: Bool {
        let value = Bundle.main.infoDictionary?["API_SSL"] as? String ?? "false"
        return value.lowercased() == "true"
    }
    
    /// HTTP 协议前缀
    static var httpScheme: String { apiSSL ? "https" : "http" }
    
    /// WebSocket 协议前缀
    static var wsScheme: String { apiSSL ? "wss" : "ws" }
    
    /// API 域名（如 frp.agcplayer.com、localhost）
    static var apiDomain: String {
        Bundle.main.infoDictionary?["API_DOMAIN"] as? String ?? DefaultValues.apiDomain
    }
    
    /// HTTP 端口
    static var apiHttpPort: String {
        Bundle.main.infoDictionary?["API_HTTP_PORT"] as? String ?? DefaultValues.apiHttpPort
    }
    
    /// WebSocket ASR 端口
    static var apiWsAsrPort: String {
        Bundle.main.infoDictionary?["API_WS_ASR_PORT"] as? String ?? DefaultValues.apiWsAsrPort
    }
    
    /// WebSocket TTS 端口
    static var apiWsTtsPort: String {
        Bundle.main.infoDictionary?["API_WS_TTS_PORT"] as? String ?? DefaultValues.apiWsTtsPort
    }
    
    /// API Key
    /// 从 Info.plist 读取（Secrets.xcconfig）
    static var apiKey: String {
        Bundle.main.infoDictionary?["API_KEY"] as? String ?? ""
    }
    
    // MARK: - 派生 URL（自动拼接协议和端口）
    
    /// 构建 URL，省略默认端口（http:80, https:443, ws:80, wss:443）
    private static func buildURL(scheme: String, domain: String, port: String) -> String {
        let defaultPorts = ["http": "80", "https": "443", "ws": "80", "wss": "443"]
        if port.isEmpty || defaultPorts[scheme] == port {
            return "\(scheme)://\(domain)"
        }
        return "\(scheme)://\(domain):\(port)"
    }
    
    /// API 基础 URL（HTTP）
    /// 优先级：UserDefaults（设置页面修改）> Info.plist (Secrets.xcconfig) > 硬编码默认值
    static var apiBaseURL: String {
        UserDefaults.standard.string(forKey: Keys.apiBaseURL) ?? defaultAPIBaseURL
    }
    
    /// 默认 API URL（从 Info.plist 的 domain + port 拼接）
    /// 用于 @AppStorage 的初始值和回退值
    static var defaultAPIBaseURL: String {
        buildURL(scheme: httpScheme, domain: apiDomain, port: apiHttpPort)
    }
    
    /// WebSocket ASR URL（语音识别）
    static var wsASRBaseURL: String {
        buildURL(scheme: wsScheme, domain: apiDomain, port: apiWsAsrPort)
    }
    
    /// WebSocket TTS URL（语音合成）
    static var wsTTSBaseURL: String {
        buildURL(scheme: wsScheme, domain: apiDomain, port: apiWsTtsPort)
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
        static let apiDomain = "localhost"
        static let apiHttpPort = "9527"
        static let apiWsAsrPort = "9525"
        static let apiWsTtsPort = "9524"
        static let apiBaseURL = "http://\(apiDomain):\(apiHttpPort)"  // 默认不使用 SSL
        static let autoTTS = true
        static let ttsRate = 1.0
        static let asrProvider = "deepgram" // native, google, deepgram
        static let asrLanguage = "zh-CN" // 默认中文
        static let ttsProvider = "google" // native（系统语音）, google（Google TTS）
        static let defaultModel = "gemini-2.5-flash" // 默认 AI 模型（支持 thinking）
        static let enableGoogleSearch = false  // 默认关闭（与 MCP 冲突）
        static let enableMCPTools = true  // 默认开启 MCP 工具
    }
}
