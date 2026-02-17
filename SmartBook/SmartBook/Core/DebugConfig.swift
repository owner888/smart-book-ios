// DebugConfig.swift - 配置调试助手
// 用于调试配置读取问题

import Foundation

enum DebugConfig {
    static func printAllConfiguration() {
        print("=== 配置调试信息 ===")
        
        // 1. 检查 Bundle.main.infoDictionary 中的值
        if let domain = Bundle.main.infoDictionary?["API_DOMAIN"] as? String {
            print("✅ Info.plist 中的 API_DOMAIN: \(domain)")
        } else {
            print("❌ Info.plist 中没有找到 API_DOMAIN")
        }
        
        if let httpPort = Bundle.main.infoDictionary?["API_HTTP_PORT"] as? String {
            print("✅ Info.plist 中的 API_HTTP_PORT: \(httpPort)")
        }
        
        if let wsAsrPort = Bundle.main.infoDictionary?["API_WS_ASR_PORT"] as? String {
            print("✅ Info.plist 中的 API_WS_ASR_PORT: \(wsAsrPort)")
        }
        
        if let wsTtsPort = Bundle.main.infoDictionary?["API_WS_TTS_PORT"] as? String {
            print("✅ Info.plist 中的 API_WS_TTS_PORT: \(wsTtsPort)")
        }
        
        // 2. 检查 UserDefaults 中的值
        if let userURL = UserDefaults.standard.string(forKey: AppConfig.Keys.apiBaseURL) {
            print("📦 UserDefaults 中的 apiBaseURL: \(userURL)")
        } else {
            print("📦 UserDefaults 中没有 apiBaseURL")
        }
        
        // 3. 检查 AppConfig 返回的最终值
        print("🎯 AppConfig.apiDomain: \(AppConfig.apiDomain)")
        print("🎯 AppConfig.apiBaseURL: \(AppConfig.apiBaseURL)")
        print("🎯 AppConfig.defaultAPIBaseURL: \(AppConfig.defaultAPIBaseURL)")
        print("🎯 AppConfig.wsASRBaseURL: \(AppConfig.wsASRBaseURL)")
        print("🎯 AppConfig.wsTTSBaseURL: \(AppConfig.wsTTSBaseURL)")
        
        print("\n===================")
    }
    
    static func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: AppConfig.Keys.apiBaseURL)
        UserDefaults.standard.synchronize()
        print("✅ 已清除 UserDefaults 中的 apiBaseURL")
    }
}
