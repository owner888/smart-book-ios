// ReaderModels.swift - 阅读器相关数据模型

import SwiftUI

// MARK: - 翻页动画类型
enum PageTurnStyle: Int, Codable, CaseIterable {
    case slide = 0      // 滑动
    case curl = 1       // 卷页（3D翻页效果）
    case fade = 2       // 淡入淡出
    
    var name: String {
        switch self {
        case .slide: return "滑动"
        case .curl: return "翻页"
        case .fade: return "淡入"
        }
    }
    
    var icon: String {
        switch self {
        case .slide: return "arrow.left.arrow.right"
        case .curl: return "book.pages"
        case .fade: return "sparkles"
        }
        
    }
    
    var description: String {
        switch self {
        case .slide: return "左右滑动切换页面，流畅自然"
        case .curl: return "模拟真实书本翻页效果，带3D动画"
        case .fade: return "页面淡入淡出切换，简洁优雅"
        }
    }
}

// MARK: - 阅读器设置模型
struct ReaderSettings: Codable {
    var fontSize: CGFloat = 18
    var fontFamily: String = "System"
    var lineSpacing: CGFloat = 8
    var backgroundColor: String = "dark" // dark, sepia, light
    var brightness: Double = 1.0
    var textAlignment: TextAlignment = .leading
    var pageTurnStyle: PageTurnStyle = .curl
    
    enum CodingKeys: String, CodingKey {
        case fontSize, fontFamily, lineSpacing, backgroundColor, brightness, textAlignment, pageTurnStyle
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 18
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily) ?? "System"
        lineSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .lineSpacing) ?? 8
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor) ?? "dark"
        brightness = try container.decodeIfPresent(Double.self, forKey: .brightness) ?? 1.0
        let alignmentRaw = try container.decodeIfPresent(Int.self, forKey: .textAlignment) ?? 0
        textAlignment = TextAlignment(rawValue: alignmentRaw) ?? .leading
        pageTurnStyle = try container.decodeIfPresent(PageTurnStyle.self, forKey: .pageTurnStyle) ?? .curl
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(fontFamily, forKey: .fontFamily)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(textAlignment.rawValue, forKey: .textAlignment)
        try container.encode(pageTurnStyle, forKey: .pageTurnStyle)
    }
    
    // 保存设置
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "ReaderSettings")
        }
    }
    
    // 加载设置
    static func load() -> ReaderSettings {
        guard let data = UserDefaults.standard.data(forKey: "ReaderSettings"),
              let settings = try? JSONDecoder().decode(ReaderSettings.self, from: data) else {
            return ReaderSettings()
        }
        return settings
    }
    
    // 根据设置获取背景色
    var bgColor: Color {
        switch backgroundColor {
        case "sepia": return Color(hex: "F4ECD8")
        case "light": return Color.white
        default: return Color(hex: "1a1a2e")
        }
    }
    
    // 根据设置获取文字颜色
    var txtColor: Color {
        switch backgroundColor {
        case "sepia": return Color(hex: "5B4636")
        case "light": return Color.black
        default: return Color.white
        }
    }
    
    // 获取当前字体
    var font: Font {
        fontFamily == "System" ? .system(size: fontSize) : .custom(fontFamily, size: fontSize)
    }
}

// MARK: - TextAlignment 扩展
extension TextAlignment {
    var rawValue: Int {
        switch self {
        case .leading: return 0
        case .center: return 1
        case .trailing: return 2
        }
    }
    
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .leading
        case 1: self = .center
        case 2: self = .trailing
        default: return nil
        }
    }
}

// MARK: - 阅读进度模型
struct ReadingProgress: Codable {
    var bookId: String
    var chapterIndex: Int
    var pageIndex: Int
    var scrollOffset: CGFloat
    var lastReadDate: Date
    
    static func load(for bookId: String) -> ReadingProgress? {
        let key = "ReadingProgress_\(bookId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let progress = try? JSONDecoder().decode(ReadingProgress.self, from: data) else {
            return nil
        }
        return progress
    }
    
    func save() {
        let key = "ReadingProgress_\(bookId)"
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - 全书页面结构
struct BookPage {
    let content: String
    let chapterIndex: Int
    let chapterTitle: String
}
