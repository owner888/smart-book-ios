// LocalizationManager.swift - 多语言管理器

import Foundation
import SwiftUI
import Combine

/// 支持的语言
enum Language: String, CaseIterable, Identifiable {
    case system = "system"  // 跟随系统
    case english = "en"     // 英文
    case simplifiedChinese = "zh-Hans"  // 简体中文
    case traditionalChinese = "zh-Hant" // 繁体中文
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return "System Default"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        }
    }
    
    var locale: Locale {
        switch self {
        case .system:
            return Locale.current
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .traditionalChinese:
            return Locale(identifier: "zh-Hant")
        }
    }
    
    /// 获取当前语言的首选语言数组
    var preferredLanguages: [String] {
        switch self {
        case .system:
            return Locale.preferredLanguages
        case .english:
            return ["en"]
        case .simplifiedChinese:
            return ["zh-Hans", "zh-Hans-CN", "zh"]
        case .traditionalChinese:
            return ["zh-Hant", "zh-Hant-TW", "zh-Hant-HK", "zh"]
        }
    }
}

/// 多语言管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: Language {
        didSet {
            saveLanguagePreference()
            applyLanguage()
        }
    }
    
    private let userDefaultsKey = "app_language"
    
    private init() {
        // 从用户设置加载保存的语言
        if let savedLanguage = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
        
        // 应用语言
        applyLanguage()
    }
    
    /// 保存语言偏好设置
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
    }
    
    /// 应用语言设置
    private func applyLanguage() {
        // 设置 SwiftUI 的本地化环境
        // 注意：SwiftUI 会自动根据 currentLanguage 环境的改变来更新视图
        
        // 对于日期、数字等格式化，使用当前语言的 locale
        if currentLanguage != .system {
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
    
    /// 获取本地化字符串
    func localize(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
    
    /// 获取带参数的本地化字符串
    func localize(_ key: String, args: CVarArg...) -> String {
        let format = localize(key)
        return String(format: format, arguments: args)
    }
}

/// 本地化视图扩展
extension View {
    /// 使用本地化字符串
    func localized(_ key: String) -> some View {
        Text(LocalizationManager.shared.localize(key))
    }
    
    /// 根据语言环境获取文本
    func localeText(_ zh: String, _ en: String) -> some View {
        let language = LocalizationManager.shared.currentLanguage
        let text: String
        switch language {
        case .system:
            text = Locale.current.language.languageCode?.identifier == "zh" ? zh : en
        case .english:
            text = en
        case .simplifiedChinese, .traditionalChinese:
            text = zh
        }
        return Text(text)
    }
}

/// 便捷本地化字符串
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// 带参数的本地化字符串
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return String(format: format, arguments: args)
}
