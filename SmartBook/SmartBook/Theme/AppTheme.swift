// AppTheme.swift - 应用主题管理

import SwiftUI

// MARK: - 主题模式
enum AppThemeMode: Int, CaseIterable, Codable {
    case system = 0  // 跟随系统
    case dark = 1    // 暗黑模式
    case light = 2   // 浅色模式
    
    var name: String {
        switch self {
        case .system: return L("settings.theme.system")
        case .dark: return L("settings.theme.dark")
        case .light: return L("settings.theme.light")
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

// MARK: - 主题颜色
struct ThemeColors {
    // 背景色
    let background: Color
    let cardBackground: Color
    let inputBackground: Color
    
    // 文字色
    let primaryText: Color
    let secondaryText: Color
    
    // 消息气泡
    let userBubble: Color
    let assistantBubble: Color
    
    // 分隔线
    let separator: Color
    
    // 导航栏
    let navigationBar: Color
    
    // 强调色
    let accentColor: Color
    
    // 暗黑主题
    static let dark = ThemeColors(
        background: Color.black,
        cardBackground: Color(white: 0.11),
        inputBackground: Color(white: 0.15),
        primaryText: Color.white,
        secondaryText: Color.gray,
        userBubble: Color(white: 0.25),
        assistantBubble: Color(white: 0.15),
        separator: Color(white: 0.2),
        navigationBar: Color.black,
        accentColor: Color.blue
    )
    
    // 浅色主题
    static let light = ThemeColors(
        background: Color(UIColor.systemGroupedBackground),
        cardBackground: Color.white,
        inputBackground: Color(UIColor.secondarySystemGroupedBackground),
        primaryText: Color.black,
        secondaryText: Color.gray,
        userBubble: Color(UIColor.systemGray5),
        assistantBubble: Color.white,
        separator: Color(UIColor.separator),
        navigationBar: Color(UIColor.systemGroupedBackground),
        accentColor: Color.blue
    )
}

// MARK: - 主题管理器
@Observable
class ThemeManager {
    static let shared = ThemeManager()
    
    var themeMode: AppThemeMode {
        didSet {
            save()
        }
    }
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: "AppThemeMode"),
           let mode = try? JSONDecoder().decode(AppThemeMode.self, from: data) {
            themeMode = mode
        } else {
            themeMode = .dark
        }
    }
    
    /// 根据系统当前颜色模式获取主题颜色
    func colors(for systemColorScheme: ColorScheme) -> ThemeColors {
        switch themeMode {
        case .system:
            return systemColorScheme == .dark ? .dark : .light
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
    
    var colorScheme: ColorScheme? {
        themeMode.colorScheme
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(themeMode) {
            UserDefaults.standard.set(data, forKey: "AppThemeMode")
        }
    }
}

// MARK: - 环境扩展
struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: ThemeColors = .dark
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

// MARK: - 视图扩展
extension View {
    func themedBackground(_ themeColors: ThemeColors) -> some View {
        self.background(themeColors.background.ignoresSafeArea())
    }
    
    func themedCardBackground(_ themeColors: ThemeColors) -> some View {
        self.background(themeColors.cardBackground)
    }
}
