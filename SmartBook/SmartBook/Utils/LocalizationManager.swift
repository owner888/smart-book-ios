// LocalizationManager.swift - 多语言管理器

import Foundation
import SwiftUI
internal import Combine

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
            return "系统"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        }
    }
    
    /// 获取语言对应的 bundle
    var bundle: Bundle {
        switch self {
        case .system:
            // 跟随系统语言
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hant") {
                return zhHantBundle
            } else if preferred.hasPrefix("zh") {
                return zhHansBundle
            } else {
                return enBundle
            }
        case .english:
            return enBundle
        case .simplifiedChinese:
            return zhHansBundle
        case .traditionalChinese:
            return zhHantBundle
        }
    }
    
    private var enBundle: Bundle {
        Bundle.main.path(forResource: "en", ofType: "lproj").flatMap { Bundle(path: $0) } ?? .main
    }
    
    private var zhHansBundle: Bundle {
        Bundle.main.path(forResource: "zh-Hans", ofType: "lproj").flatMap { Bundle(path: $0) } ?? .main
    }
    
    private var zhHantBundle: Bundle {
        Bundle.main.path(forResource: "zh-Hant", ofType: "lproj").flatMap { Bundle(path: $0) } ?? .main
    }
}

/// 多语言管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: Language {
        didSet {
            saveLanguagePreference()
            // 通知视图语言已更改
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
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
    }
    
    /// 保存语言偏好设置
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
    }
    
    /// 根据当前语言获取本地化字符串
    func localize(_ key: String) -> String {
        currentLanguage.bundle.localizedString(forKey: key, value: key, table: nil)
    }
    
    /// 带参数的本地化字符串
    func localize(_ key: String, args: CVarArg...) -> String {
        let format = localize(key)
        return String(format: format, arguments: args)
    }
}

/// 语言切换通知
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

/// 本地化视图扩展
extension View {
    /// 根据当前语言获取文本
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

/// 便捷本地化函数 - 根据当前语言获取字符串
func L(_ key: String) -> String {
    LocalizationManager.shared.localize(key)
}

/// 带参数的本地化字符串
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = L(key)
    return String(format: format, arguments: args)
}
