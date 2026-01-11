// LocalizationManager.swift - 多语言管理器（纯 Swift 实现，无需 Combine）

import Foundation
import SwiftUI
import Combine

/// 支持的语言
enum Language: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "系统"
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }
    
    /// 获取语言对应的 bundle
    var bundle: Bundle {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hant") {
                return zhHantBundle
            } else if preferred.hasPrefix("zh") {
                return zhHansBundle
            } else {
                return enBundle
            }
        case .english: return enBundle
        case .simplifiedChinese: return zhHansBundle
        case .traditionalChinese: return zhHantBundle
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

/// 简单的 observable 对象，不使用 @Published
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
            objectWillChange.send()
        }
    }
    
    let objectWillChange = ObservableObjectPublisher()
    
    private let userDefaultsKey = "app_language"
    
    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
    }
    
    /// 根据当前语言获取本地化字符串
    func localize(_ key: String) -> String {
        currentLanguage.bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

/// 便捷本地化视图 - 自动响应语言变化
struct LocalizedText: View {
    let key: String
    @EnvironmentObject var localizationManager: LocalizationManager
    
    var body: some View {
        Text(localizationManager.localize(key))
    }
}

/// 便捷全局函数
func L(_ key: String) -> String {
    LocalizationManager.shared.localize(key)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = LocalizationManager.shared.localize(key)
    return String(format: format, arguments: args)
}

/// 根据当前语言获取文本
func localeText(_ zh: String, _ en: String) -> String {
    let language = LocalizationManager.shared.currentLanguage
    switch language {
    case .system:
        return Locale.current.language.languageCode?.identifier == "zh" ? zh : en
    case .english:
        return en
    case .simplifiedChinese, .traditionalChinese:
        return zh
    }
}
