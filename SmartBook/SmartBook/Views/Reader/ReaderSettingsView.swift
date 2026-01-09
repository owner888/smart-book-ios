// ReaderSettingsView.swift - 阅读器设置视图（iOS 深色系统设置风格）

import SwiftUI

struct ReaderSettingsView: View {
    @Binding var settings: ReaderSettings
    @Environment(\.dismiss) private var dismiss
    
    private let fontFamilies = ["System", "PingFang SC", "Heiti SC", "STSong", "Kaiti SC"]
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 显示设置
                Section {
                    // 字体大小
                    SettingsRow(icon: "textformat.size", iconColor: .blue, title: "字体大小") {
                        Stepper("\(Int(settings.fontSize))", value: $settings.fontSize, in: 14...28, step: 1)
                            .labelsHidden()
                    }
                    
                    // 字体
                    SettingsRow(icon: "character", iconColor: .purple, title: "字体") {
                        Picker("", selection: $settings.fontFamily) {
                            ForEach(fontFamilies, id: \.self) { family in
                                Text(family).tag(family)
                            }
                        }
                        .labelsHidden()
                        .tint(.gray)
                    }
                    
                    // 行间距
                    SettingsRow(icon: "text.alignleft", iconColor: .green, title: "行间距") {
                        Stepper("\(Int(settings.lineSpacing))", value: $settings.lineSpacing, in: 4...16, step: 2)
                            .labelsHidden()
                    }
                } header: {
                    Text("显示")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
                
                // MARK: - 主题设置
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "paintpalette", color: .orange)
                            Text("背景色")
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 16) {
                            ForEach(BackgroundOption.allCases, id: \.self) { option in
                                BackgroundColorButton(
                                    option: option,
                                    isSelected: settings.backgroundColor == option.rawValue
                                ) {
                                    settings.backgroundColor = option.rawValue
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("主题")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
                
                // MARK: - 排版设置
                Section {
                    // 文字对齐
                    SettingsRow(icon: "text.justify.left", iconColor: .cyan, title: "文字对齐") {
                        Picker("", selection: $settings.textAlignment) {
                            Text("左对齐").tag(TextAlignment.leading)
                            Text("居中").tag(TextAlignment.center)
                            Text("右对齐").tag(TextAlignment.trailing)
                        }
                        .labelsHidden()
                        .tint(.gray)
                    }
                    
                    // 翻页效果
                    SettingsRow(icon: "book.pages", iconColor: .pink, title: "翻页效果") {
                        Picker("", selection: $settings.pageTurnStyle) {
                            ForEach(PageTurnStyle.allCases, id: \.self) { style in
                                Text(style.name).tag(style)
                            }
                        }
                        .labelsHidden()
                        .tint(.gray)
                    }
                } header: {
                    Text("排版")
                        .foregroundColor(.gray)
                } footer: {
                    Text(settings.pageTurnStyle.description)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
                
                // MARK: - 预览
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("预览效果")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("这是一段预览文字，用于展示当前的阅读设置效果。")
                            .font(settings.font)
                            .lineSpacing(settings.lineSpacing)
                            .multilineTextAlignment(settings.textAlignment)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: alignmentFor(settings.textAlignment))
                            .background(settings.bgColor)
                            .foregroundColor(settings.txtColor)
                            .cornerRadius(12)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("预览")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        settings.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func alignmentFor(_ alignment: TextAlignment) -> Alignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

// MARK: - 背景色选项
enum BackgroundOption: String, CaseIterable {
    case dark = "dark"
    case sepia = "sepia"
    case light = "light"
    
    var color: Color {
        switch self {
        case .dark: return Color(hex: "1a1a2e")
        case .sepia: return Color(hex: "F4ECD8")
        case .light: return Color.white
        }
    }
    
    var name: String {
        switch self {
        case .dark: return "深色"
        case .sepia: return "护眼"
        case .light: return "浅色"
        }
    }
    
    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .sepia: return "leaf.fill"
        case .light: return "sun.max.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .dark: return .purple
        case .sepia: return .orange
        case .light: return .yellow
        }
    }
}

// MARK: - 背景色按钮
struct BackgroundColorButton: View {
    let option: BackgroundOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(option.color)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.4), lineWidth: isSelected ? 3 : 1)
                        )
                    
                    Image(systemName: option.icon)
                        .foregroundColor(option.iconColor)
                        .font(.system(size: 18))
                }
                
                Text(option.name)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
        }
        .buttonStyle(.plain)
    }
}
