// SettingsView.swift - 设置视图（支持主题切换）

import SwiftUI
internal import AVFAudio

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @AppStorage("apiBaseURL") private var apiBaseURL = "http://localhost:8080"
    @AppStorage("autoTTS") private var autoTTS = true
    @AppStorage("ttsRate") private var ttsRate = 1.0
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 外观设置
                Section {
                    // 主题选择
                    HStack(spacing: 12) {
                        SettingsIcon(icon: "paintbrush", color: .purple)
                        Text("外观")
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
                    Text("外观")
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)
                
                // 服务器设置
                Section {
                    SettingsRow(icon: "server.rack", iconColor: .teal, title: apiBaseURL, colors: colors) {
                        EmptyView()
                    }
                    .contextMenu {
                        Button("编辑") { }
                    }
                } header: {
                    Text("服务器")
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)
                
                // 语音设置
                Section {
                    // 自动朗读
                    HStack(spacing: 12) {
                        SettingsIcon(icon: "speaker.wave.2", color: .orange)
                        Text("自动朗读 AI 回复")
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        Toggle("", isOn: $autoTTS)
                            .labelsHidden()
                    }
                    
                    // 语速
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "speedometer", color: .green)
                            Text("语速")
                                .foregroundColor(colors.primaryText)
                            Spacer()
                            Text(String(format: "%.1fx", ttsRate))
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
                            Text("选择语音")
                                .foregroundColor(colors.primaryText)
                        }
                    }
                } header: {
                    Text("语音")
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)
                
                // 关于
                Section {
                    SettingsRow(icon: "info.circle", iconColor: .cyan, title: "版本", colors: colors) {
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
                    Text("关于")
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(colors.background.ignoresSafeArea())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(colors.navigationBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onChange(of: ttsRate) { _, newValue in
            appState.ttsService.rate = Float(newValue)
        }
    }
}

// MARK: - 设置项图标
struct SettingsIcon: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - 设置项行
struct SettingsRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    var colors: ThemeColors = .dark
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(icon: icon, color: iconColor)
            Text(title)
                .foregroundColor(colors.primaryText)
            Spacer()
            content()
        }
    }
}

// MARK: - 语音选择视图
struct VoiceSelectionView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var selectedVoiceId: String = ""
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        List(appState.ttsService.availableVoices, id: \.identifier) { voice in
            HStack {
                VStack(alignment: .leading) {
                    Text(voice.name)
                        .font(.headline)
                        .foregroundColor(colors.primaryText)
                    Text(voice.language)
                        .font(.caption)
                        .foregroundColor(colors.secondaryText)
                }
                
                Spacer()
                
                if voice.identifier == selectedVoiceId {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedVoiceId = voice.identifier
                appState.ttsService.selectedVoice = voice
            }
            .listRowBackground(colors.cardBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("选择语音")
        .toolbarBackground(colors.navigationBar, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            selectedVoiceId = appState.ttsService.selectedVoice?.identifier ?? ""
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .environment(ThemeManager.shared)
}
