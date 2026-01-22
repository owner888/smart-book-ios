// DebugConfig.swift - 配置调试助手
// 用于调试配置读取问题

import Foundation

enum DebugConfig {
    static func printAllConfiguration() {
        print("=== 配置调试信息 ===")
        
        // 1. 检查 Bundle.main.infoDictionary 中的值
        if let apiBaseURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String {
            print("✅ Info.plist 中的 API_BASE_URL: \(apiBaseURL)")
        } else {
            print("❌ Info.plist 中没有找到 API_BASE_URL")
        }
        
        // 2. 检查 UserDefaults 中的值
        if let userURL = UserDefaults.standard.string(forKey: AppConfig.Keys.apiBaseURL) {
            print("📦 UserDefaults 中的 apiBaseURL: \(userURL)")
        } else {
            print("📦 UserDefaults 中没有 apiBaseURL")
        }
        
        // 3. 检查 AppConfig 返回的最终值
        print("🎯 AppConfig.apiBaseURL: \(AppConfig.apiBaseURL)")
        print("🎯 AppConfig.defaultAPIBaseURL: \(AppConfig.defaultAPIBaseURL)")
        
        // 4. 打印所有 Info.plist 内容
        // print("\n=== 完整 Info.plist 内容 ===")
        // if let dict = Bundle.main.infoDictionary {
        //     for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
        //         print("\(key): \(value)")
        //     }
        // }
        
        print("\n===================")
    }
    
    static func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: AppConfig.Keys.apiBaseURL)
        UserDefaults.standard.synchronize()
        print("✅ 已清除 UserDefaults 中的 apiBaseURL")
    }
}
