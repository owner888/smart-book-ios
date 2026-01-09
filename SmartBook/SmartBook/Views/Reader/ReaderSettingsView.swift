// ReaderSettingsView.swift - 阅读器设置视图

import SwiftUI

struct ReaderSettingsView: View {
    @Binding var settings: ReaderSettings
    @Environment(\.dismiss) private var dismiss
    
    private let fontFamilies = ["System", "PingFang SC", "Heiti SC", "STSong", "Kaiti SC"]
    private let backgroundOptions: [(String, String, Color)] = [
        ("dark", "深色", Color(hex: "1a1a2e")),
        ("sepia", "护眼", Color(hex: "F4ECD8")),
        ("light", "浅色", Color.white)
    ]
    
    var body: some View {
        NavigationStack {
            List {
                fontSizeSection
                fontFamilySection
                lineSpacingSection
                backgroundColorSection
                textAlignmentSection
                pageTurnStyleSection
                previewSection
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        settings.save()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 字体大小
    private var fontSizeSection: some View {
        Section("字体大小") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("A").font(.system(size: 14))
                    Slider(value: $settings.fontSize, in: 14...28, step: 1)
                    Text("A").font(.system(size: 28))
                }
                Text("当前字号：\(Int(settings.fontSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 字体选择
    private var fontFamilySection: some View {
        Section("字体") {
            Picker("字体", selection: $settings.fontFamily) {
                ForEach(fontFamilies, id: \.self) { family in
                    Text(family)
                        .font(family == "System" ? .system(size: 16) : .custom(family, size: 16))
                        .tag(family)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    // MARK: - 行间距
    private var lineSpacingSection: some View {
        Section("行间距") {
            VStack(alignment: .leading, spacing: 12) {
                Slider(value: $settings.lineSpacing, in: 4...16, step: 2)
                Text("当前行距：\(Int(settings.lineSpacing))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 背景色
    private var backgroundColorSection: some View {
        Section("背景色") {
            HStack(spacing: 16) {
                ForEach(backgroundOptions, id: \.0) { option in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(option.2)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(settings.backgroundColor == option.0 ? Color.blue : Color.gray.opacity(0.3), lineWidth: 3)
                            )
                            .onTapGesture {
                                settings.backgroundColor = option.0
                            }
                        
                        Text(option.1)
                            .font(.caption)
                            .foregroundColor(settings.backgroundColor == option.0 ? .blue : .secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 文字对齐
    private var textAlignmentSection: some View {
        Section("文字对齐") {
            Picker("对齐方式", selection: $settings.textAlignment) {
                Text("左对齐").tag(TextAlignment.leading)
                Text("居中").tag(TextAlignment.center)
                Text("右对齐").tag(TextAlignment.trailing)
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - 翻页效果
    private var pageTurnStyleSection: some View {
        Section("翻页效果") {
            Picker("翻页样式", selection: $settings.pageTurnStyle) {
                ForEach(PageTurnStyle.allCases, id: \.self) { style in
                    HStack {
                        Image(systemName: style.icon)
                        Text(style.name)
                    }
                    .tag(style)
                }
            }
            .pickerStyle(.segmented)
            
            Text(settings.pageTurnStyle.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    // MARK: - 预览
    private var previewSection: some View {
        Section("预览") {
            Text("这是一段预览文字，用于展示当前的阅读设置效果。调整上方的设置可以实时看到变化。")
                .font(settings.font)
                .lineSpacing(settings.lineSpacing)
                .multilineTextAlignment(settings.textAlignment)
                .padding()
                .background(settings.bgColor)
                .foregroundColor(settings.txtColor)
                .cornerRadius(8)
        }
    }
}
