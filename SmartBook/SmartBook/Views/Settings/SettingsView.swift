// SettingsView.swift - 设置视图（支持主题切换和多语言）

import SwiftUI

struct SettingsView: View {
    @Environment(BookState.self) var bookState
    @Environment(ThemeManager.self) var themeManager
    @EnvironmentObject var ttsService: TTSService
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.dismiss) var dismiss
    @AppStorage(AppConfig.Keys.apiBaseURL) private var apiBaseURL = AppConfig.defaultAPIBaseURL
    @AppStorage(AppConfig.Keys.twitterParserSource) private var twitterParserSource = AppConfig.DefaultValues
        .twitterParserSource
    @AppStorage(AppConfig.Keys.cobaltApiKey) private var cobaltApiKey = AppConfig.defaultCobaltApiKey
    @AppStorage(AppConfig.Keys.autoTTS) private var autoTTS = AppConfig.DefaultValues.autoTTS
    @AppStorage(AppConfig.Keys.ttsRate) private var ttsRate = AppConfig.DefaultValues.ttsRate
    @AppStorage(AppConfig.Keys.asrProvider) private var asrProvider = AppConfig.DefaultValues.asrProvider
    @AppStorage(AppConfig.Keys.asrLanguage) private var asrLanguage = AppConfig.DefaultValues.asrLanguage
    @AppStorage(AppConfig.Keys.ttsProvider) private var ttsProvider = AppConfig.DefaultValues.ttsProvider
    @AppStorage(AppConfig.Keys.enableGoogleSearch) private var enableGoogleSearch = AppConfig.DefaultValues
        .enableGoogleSearch
    @AppStorage(AppConfig.Keys.enableMCPTools) private var enableMCPTools = AppConfig.DefaultValues.enableMCPTools
    @AppStorage(AppConfig.Keys.aiDataConsentGiven) private var aiDataConsentGiven = false

    @State private var showServerEditor = false
    @State private var editingURL = ""
    @State private var showResetAlert = false
    @State private var showClearCacheAlert = false
    @State private var showPrivacyPolicy = false

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

                    // App 语言 - 跳转到系统设置
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "globe", color: .blue)
                            Text(L("settings.appLanguage"))
                                .foregroundColor(colors.primaryText)
                            Spacer()
                            Text(currentLanguageName())
                                .font(.subheadline)
                                .foregroundColor(colors.secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(colors.secondaryText)
                        }
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

                    HStack(spacing: 12) {
                        SettingsIcon(icon: "network", color: .indigo)
                        Text(L("settings.videoParserSource"))
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        Picker("", selection: $twitterParserSource) {
                            Text("自动").tag("auto")
                            Text("x2twitter").tag("x2twitter")
                            Text("cobalt").tag("cobalt")
                        }
                        .labelsHidden()
                        .tint(colors.secondaryText)
                    }

                    HStack(spacing: 12) {
                        SettingsIcon(icon: "key.fill", color: .orange)
                        Text("Cobalt API Key")
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        SecureField("可选", text: $cobaltApiKey)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundColor(colors.secondaryText)
                            .frame(maxWidth: 200)
                    }
                } header: {
                    Text(L("server.title"))
                        .foregroundColor(colors.secondaryText)
                } footer: {
                    // Text(L("server.description"))
                    // .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)

                // 语音设置
                Section {
                    // ASR 提供商选择
                    HStack(spacing: 12) {
                        SettingsIcon(icon: "mic", color: .blue)
                        Text(L("settings.asr.provider"))
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        Picker("", selection: $asrProvider) {
                            Text(L("settings.asr.provider.native")).tag("native")
                            Text(L("settings.asr.provider.google")).tag("google")
                            Text(L("settings.asr.provider.deepgram")).tag("deepgram")
                        }
                        .labelsHidden()
                        .tint(colors.secondaryText)
                    }

                    // 语言选择
                    HStack(spacing: 12) {
                        SettingsIcon(icon: "globe", color: .cyan)
                        Text(L("settings.asr.language"))
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        Picker("", selection: $asrLanguage) {
                            Text(L("settings.asr.language.chinese")).tag("zh-CN")
                            Text(L("settings.asr.language.english")).tag("en-US")
                            Text(L("settings.asr.language.japanese")).tag("ja")
                            Text(L("settings.asr.language.korean")).tag("ko")
                            Text(L("settings.asr.language.french")).tag("fr")
                            Text(L("settings.asr.language.german")).tag("de")
                            Text(L("settings.asr.language.spanish")).tag("es")
                            Text(L("settings.asr.language.thai")).tag("th")
                        }
                        .labelsHidden()
                        .tint(colors.secondaryText)
                    }

                    // TTS 提供商选择
                    HStack(spacing: 12) {
                        SettingsIcon(icon: "speaker.wave.3", color: .purple)
                        Text(L("settings.tts.provider"))
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        Picker("", selection: $ttsProvider) {
                            Text(L("settings.tts.provider.native")).tag("native")
                            Text(L("settings.tts.provider.google")).tag("google")
                        }
                        .labelsHidden()
                        .tint(colors.secondaryText)
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

                    // 语速（仅 iOS 原生 TTS）
                    if ttsProvider == "native" {
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
                    }
                } header: {
                    Text(L("voice.title"))
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)

                // AI 工具设置
                Section {
                    // MCP 工具开关
                    Toggle(isOn: $enableMCPTools) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "wrench.and.screwdriver.fill", color: .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("settings.aiTools.mcp"))
                                    .foregroundColor(colors.primaryText)
                                Text(L("settings.aiTools.mcp.desc"))
                                    .font(.caption)
                                    .foregroundColor(colors.secondaryText)
                            }
                        }
                    }
                    .tint(.green)

                    // Google Search 开关
                    Toggle(isOn: $enableGoogleSearch) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "magnifyingglass", color: .green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("settings.aiTools.googleSearch"))
                                    .foregroundColor(colors.primaryText)
                                Text(L("settings.aiTools.googleSearch.desc"))
                                    .font(.caption)
                                    .foregroundColor(colors.secondaryText)
                            }
                        }
                    }
                    .tint(.green)

                } header: {
                    Text(L("settings.aiTools"))
                        .foregroundColor(colors.secondaryText)
                } footer: {
                    if enableGoogleSearch && enableMCPTools {
                        Text(L("settings.aiTools.conflict"))
                            .foregroundColor(.orange)
                    } else {
                        Text(L("settings.aiTools.description"))
                            .foregroundColor(colors.secondaryText)
                    }
                }
                .listRowBackground(colors.cardBackground)

                // AI 数据隐私
                Section {
                    // AI 数据共享同意开关
                    Toggle(isOn: $aiDataConsentGiven) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "hand.raised.fill", color: .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("settings.privacy.aiConsent"))
                                    .foregroundColor(colors.primaryText)
                                Text(L("settings.privacy.aiConsent.desc"))
                                    .font(.caption)
                                    .foregroundColor(colors.secondaryText)
                            }
                        }
                    }
                    .tint(.green)

                    // 查看隐私政策
                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "doc.text", color: .blue)
                            Text(L("settings.privacyPolicy"))
                                .foregroundColor(colors.primaryText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(colors.secondaryText)
                        }
                    }
                } header: {
                    Text(L("settings.privacy.title"))
                        .foregroundColor(colors.secondaryText)
                } footer: {
                    Text(L("settings.privacy.footer"))
                        .foregroundColor(colors.secondaryText)
                }
                .listRowBackground(colors.cardBackground)

                // 数据管理
                Section {
                    // 重置设置
                    Button {
                        showResetAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "arrow.counterclockwise", color: .blue)
                            Text(L("data.resetSettings"))
                                .foregroundColor(colors.primaryText)
                        }
                    }

                    // 清除缓存
                    Button {
                        showClearCacheAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "trash", color: .red)
                            Text(L("data.clearCache"))
                                .foregroundColor(colors.primaryText)
                            Spacer()
                            Text(calculateCacheSize())
                                .font(.caption)
                                .foregroundColor(colors.secondaryText)
                        }
                    }
                } header: {
                    Text(L("data.title"))
                        .foregroundColor(colors.secondaryText)
                } footer: {
                    Text(L("data.description"))
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
            .alert(L("data.resetSettings.title"), isPresented: $showResetAlert) {
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("data.resetSettings.confirm"), role: .destructive) {
                    resetAllSettings()
                }
            } message: {
                Text(L("data.resetSettings.message"))
            }
            .alert(L("data.clearCache.title"), isPresented: $showClearCacheAlert) {
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("data.clearCache.confirm"), role: .destructive) {
                    clearCache()
                }
            } message: {
                Text(L("data.clearCache.message"))
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyWebView()
            }
        }
        .onChange(of: ttsRate) { _, newValue in
            ttsService.rate = Float(newValue)
        }
    }

    // MARK: - Helper Methods

    /// 重置所有设置到默认值
    private func resetAllSettings() {
        apiBaseURL = AppConfig.defaultAPIBaseURL
        asrProvider = AppConfig.DefaultValues.asrProvider
        asrLanguage = AppConfig.DefaultValues.asrLanguage
        ttsProvider = AppConfig.DefaultValues.ttsProvider
        autoTTS = AppConfig.DefaultValues.autoTTS
        ttsRate = AppConfig.DefaultValues.ttsRate
        enableGoogleSearch = AppConfig.DefaultValues.enableGoogleSearch
        enableMCPTools = AppConfig.DefaultValues.enableMCPTools
    }

    /// 计算缓存大小
    private func calculateCacheSize() -> String {
        guard let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return "0 KB"
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )
            let totalSize = contents.reduce(0) { size, url in
                let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return size + fileSize
            }
            return formatBytes(totalSize)
        } catch {
            return "0 KB"
        }
    }

    /// 清除缓存
    private func clearCache() {
        guard let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            for fileURL in contents {
                try? FileManager.default.removeItem(at: fileURL)
            }

            // 清除 URLCache
            URLCache.shared.removeAllCachedResponses()
        } catch {
            print("清除缓存失败: \(error)")
        }
    }

    /// 获取当前 App 语言名称
    private func currentLanguageName() -> String {
        guard let preferredLanguage = Bundle.main.preferredLocalizations.first else {
            return L("settings.language.system")
        }
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: preferredLanguage)?.capitalized
            ?? preferredLanguage
    }

    /// 格式化字节大小
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(BookState())
        .environment(ThemeManager.shared)
}
