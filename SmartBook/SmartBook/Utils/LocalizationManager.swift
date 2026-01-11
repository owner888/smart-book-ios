// LocalizationManager.swift - 跟随系统语言的本地化管理器

import Foundation
import SwiftUI

/// 便捷全局函数 - 使用标准 NSLocalizedString，自动跟随系统语言
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// 带参数的本地化字符串
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return String(format: format, arguments: args)
}

/// 根据当前系统语言获取文本
func localeText(_ zh: String, _ en: String) -> String {
    Locale.current.language.languageCode?.identifier == "zh" ? zh : en
}
