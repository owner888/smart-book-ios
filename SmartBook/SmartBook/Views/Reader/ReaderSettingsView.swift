// ReaderSettingsView.swift - 阅读器设置视图（支持多语言）

import SwiftUI

struct ReaderSettingsView: View {
    @Binding var settings: ReaderSettings
    @Environment(\.dismiss) private var dismiss
    
    private let fontFamilies = ["System", "PingFang SC", "Heiti SC", "STSong", "Kaiti SC"]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    SettingsRow(icon: "textformat.size", iconColor: .teal, title: L("reader.fontSize")) {
                        Stepper("\(Int(settings.fontSize))", value: $settings.fontSize, in: 14...28, step: 1)
                            .labelsHidden()
                    }
                    
                    SettingsRow(icon: "character", iconColor: .purple, title: L("reader.fontFamily")) {
                        Picker("", selection: $settings.fontFamily) {
                            ForEach(fontFamilies, id: \.self) { family in
                                Text(family).tag(family)
                            }
                        }
                        .labelsHidden()
                        .tint(.gray)
                    }
                    
                    SettingsRow(icon: "text.alignleft", iconColor: .green, title: L("reader.lineSpacing")) {
                        Stepper("\(Int(settings.lineSpacing))", value: $settings.lineSpacing, in: 4...16, step: 2)
                            .labelsHidden()
                    }
                } header: {
                    Text(L("settings.appearance"))
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
                
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "paintpalette", color: .orange)
                            Text(L("reader.theme"))
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
                    Text(L("reader.theme"))
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
                
                Section {
                    SettingsRow(icon: "text.justify.left", iconColor: .cyan, title: L("reader.textAlignment")) {
                        Picker("", selection: $settings.textAlignment) {
                            Text(L("reader.textAlignment.leading")).tag(TextAlignment.leading)
                            Text(L("reader.textAlignment.center")).tag(TextAlignment.center)
                            Text(L("reader.textAlignment.trailing")).tag(TextAlignment.trailing)
                        }
                        .labelsHidden()
                        .tint(.gray)
                    }
                    
                    SettingsRow(icon: "book.pages", iconColor: .pink, title: L("reader.pageTurnStyle")) {
                        Picker("", selection: $settings.pageTurnStyle) {
                            ForEach(PageTurnStyle.allCases, id: \.self) { style in
                                Text(style.name).tag(style)
                            }
                        }
                        .labelsHidden()
                        .tint(.gray)
                    }
                } header: {
                    Text(L("settings.reading"))
                        .foregroundColor(.gray)
                } footer: {
                    Text(settings.pageTurnStyle.description)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("settings.preview"))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(L("reader.previewText"))
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
                    Text(L("settings.preview"))
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common.done")) {
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
        case .dark: return L("reader.theme.dark")
        case .sepia: return L("reader.theme.sepia")
        case .light: return L("reader.theme.light")
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
                                .stroke(isSelected ? Color.green : Color.gray.opacity(0.4), lineWidth: isSelected ? 3 : 1)
                        )
                    
                    Image(systemName: option.icon)
                        .foregroundColor(option.iconColor)
                        .font(.system(size: 18))
                }
                
                Text(option.name)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .green : .gray)
            }
        }
        .buttonStyle(.plain)
    }
}
