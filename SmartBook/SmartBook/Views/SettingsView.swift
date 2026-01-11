// SettingsView.swift - 设置视图（支持主题切换和多语言）

import SwiftUI
internal import AVFAudio

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var systemColorScheme
    @AppStorage("apiBaseURL") private var apiBaseURL = "http://localhost:8080"
    @AppStorage("autoTTS") private var autoTTS = true
    @AppStorage("ttsRate") private var ttsRate = 1.0
    
    @State private var showServerEditor = false
    @State private var editingURL = ""
    @State private var selectedLanguage: Language = .system
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 通用设置
                Section {
                    // 语言选择
                    HStack(spacing: 12) {
                        SettingsIcon(icon: "globe", color: .blue)
                        Text(L("settings.language"))
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        Picker("", selection: $selectedLanguage) {
                            ForEach(Language.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .tint(colors.secondaryText)
                    }
                    
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
                                Text("服务器地址")
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
                    Text("服务器")
                        .foregroundColor(colors.secondaryText)
                } footer: {
                    Text("PHP 后端服务器地址，用于 AI 对话和书籍搜索")
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
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showServerEditor) {
                ServerEditorView(url: $editingURL, colors: colors) { newURL in
                    apiBaseURL = newURL
                    showServerEditor = false
                }
            }
        }
        .onChange(of: ttsRate) { _, newValue in
            appState.ttsService.rate = Float(newValue)
        }
        .onChange(of: selectedLanguage) { _, newValue in
            localizationManager.currentLanguage = newValue
        }
        .onAppear {
            selectedLanguage = localizationManager.currentLanguage
        }
    }
}

// MARK: - 服务器地址编辑视图
struct ServerEditorView: View {
    @Binding var url: String
    var colors: ThemeColors
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var isValid = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 输入框
                    VStack(alignment: .leading, spacing: 8) {
                        Text("服务器地址")
                            .font(.headline)
                            .foregroundColor(colors.primaryText)
                        
                        TextField("http://localhost:8080", text: $url)
                            .textFieldStyle(.plain)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(colors.cardBackground)
                            .cornerRadius(10)
                            .foregroundColor(colors.primaryText)
                            .focused($isFocused)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isValid ? Color.clear : Color.red, lineWidth: 1)
                            )
                        
                        if !isValid {
                            Text("请输入有效的 URL 地址")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(colors.cardBackground)
                    .cornerRadius(12)
                    
                    // 常用地址
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷设置")
                            .font(.headline)
                            .foregroundColor(colors.primaryText)
                        
                        ForEach(quickURLs, id: \.self) { quickURL in
                            Button {
                                url = quickURL
                            } label: {
                                HStack {
                                    Text(quickURL)
                                        .foregroundColor(colors.primaryText)
                                    Spacer()
                                    if url == quickURL {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(12)
                                .background(colors.inputBackground)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(colors.cardBackground)
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("编辑服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.navigationBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(colors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if validateURL(url) {
                            onSave(url)
                        } else {
                            isValid = false
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                }
            }
            .onAppear {
                isFocused = true
            }
            .onChange(of: url) { _, _ in
                isValid = true
            }
        }
    }
    
    private var quickURLs: [String] {
        [
            "http://localhost:8080",
            "http://127.0.0.1:8080",
            "http://192.168.1.100:8080"
        ]
    }
    
    private func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https",
              url.host != nil else {
            return false
        }
        return true
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
        .environmentObject(LocalizationManager.shared)
}
