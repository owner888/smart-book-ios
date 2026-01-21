// SettingsView.swift - 设置视图（支持主题切换和多语言）

import SwiftUI

struct SettingsView: View {
    @Environment(BookState.self) var bookState
    @Environment(ThemeManager.self) var themeManager
    @Environment(TTSService.self) var ttsService
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.dismiss) var dismiss
    @AppStorage(AppConfig.Keys.apiBaseURL) private var apiBaseURL = AppConfig.defaultAPIBaseURL
    @AppStorage(AppConfig.Keys.autoTTS) private var autoTTS = AppConfig.DefaultValues.autoTTS
    @AppStorage(AppConfig.Keys.ttsRate) private var ttsRate = AppConfig.DefaultValues.ttsRate
    
    @State private var showServerEditor = false
    @State private var editingURL = ""
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 通用设置
                Section {
                    // 主题选择
                    HStack(spacing: 12) {
                        SettingsIcon(icon: "paintbrush", color: .purple)
                        Text(L("settings.theme"))
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        Picker("", selection: Bindable(themeManager).themeMode) {
                            ForEach(AppThemeMode.allCases, id: \.self) { mode in
                                Label(mode.name, systemImage: mode.icon).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .tint(colors.secondaryText)
                    }
                } header: {
                    Text(L("settings.general"))
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)
                
                // 服务器设置
                Section {
                    Button {
                        editingURL = apiBaseURL
                        showServerEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "server.rack", color: .teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("server.address"))
                                    .foregroundColor(colors.primaryText)
                                Text(apiBaseURL)
                                    .font(.caption)
                                    .foregroundColor(colors.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(colors.secondaryText)
                        }
                    }
                } header: {
                    Text(L("server.title"))
                        .foregroundColor(colors.secondaryText)
                } footer: {
                    Text(L("server.description"))
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)
                
                // 语音设置
                Section {
                    // 自动朗读
                    HStack(spacing: 12) {
                        SettingsIcon(icon: "speaker.wave.2", color: .orange)
                        Text(L("voice.autoPlay"))
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        Toggle("", isOn: $autoTTS)
                            .labelsHidden()
                    }
                    
                    // 语速
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "speedometer", color: .green)
                            Text(L("voice.rate"))
                                .foregroundColor(colors.primaryText)
                            Spacer()
                            Text(String(format: L("voice.rate.value"), ttsRate))
                                .foregroundColor(colors.secondaryText)
                        }
                        Slider(value: $ttsRate, in: 0.5...2.0, step: 0.1)
                            .tint(.green)
                    }
                    
                    // 语音选择
                    NavigationLink {
                        VoiceSelectionView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "waveform", color: .purple)
                            Text(L("voice.select"))
                                .foregroundColor(colors.primaryText)
                        }
                    }
                } header: {
                    Text(L("voice.title"))
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)
                
                // 关于
                Section {
                    SettingsRow(icon: "info.circle", iconColor: .cyan, title: L("settings.version"), colors: colors) {
                        Text("1.0.0")
                            .foregroundColor(colors.secondaryText)
                    }
                    
                    Link(destination: URL(string: "https://github.com")!) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "link", color: .pink)
                            Text("GitHub")
                                .foregroundColor(colors.primaryText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(colors.secondaryText)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text(L("settings.about"))
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(colors.background.ignoresSafeArea())
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(colors.primaryText)
                    }
                }
            }
            .sheet(isPresented: $showServerEditor) {
                ServerEditorView(url: $editingURL, colors: colors) { newURL in
                    apiBaseURL = newURL
                    showServerEditor = false
                }
            }
        }
        .onChange(of: ttsRate) { _, newValue in
            ttsService.rate = Float(newValue)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(BookState())
        .environment(ThemeManager.shared)
}
