// SettingsView.swift - 设置视图（iOS 深色系统设置风格）

import SwiftUI
internal import AVFAudio

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @AppStorage("apiBaseURL") private var apiBaseURL = "http://localhost:8080"
    @AppStorage("autoTTS") private var autoTTS = true
    @AppStorage("ttsRate") private var ttsRate = 1.0
    
    var body: some View {
        NavigationStack {
            List {
                // 服务器设置
                Section {
                    SettingsRow(icon: "server.rack", iconColor: .blue, title: apiBaseURL) {
                        EmptyView()
                    }
                    .contextMenu {
                        Button("编辑") { }
                    }
                } header: {
                    Text("服务器")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
                
                // 语音设置
                Section {
                    // 自动朗读
                    HStack(spacing: 12) {
                        SettingsIcon(icon: "speaker.wave.2", color: .orange)
                        Text("自动朗读 AI 回复")
                            .foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: $autoTTS)
                            .labelsHidden()
                    }
                    
                    // 语速
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "speedometer", color: .green)
                            Text("语速")
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1fx", ttsRate))
                                .foregroundColor(.gray)
                        }
                        Slider(value: $ttsRate, in: 0.5...2.0, step: 0.1)
                            .tint(.blue)
                    }
                    
                    // 语音选择
                    NavigationLink {
                        VoiceSelectionView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "waveform", color: .purple)
                            Text("选择语音")
                                .foregroundColor(.white)
                        }
                    }
                } header: {
                    Text("语音")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
                
                // 关于
                Section {
                    SettingsRow(icon: "info.circle", iconColor: .cyan, title: "版本") {
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    Link(destination: URL(string: "https://github.com")!) {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: "link", color: .pink)
                            Text("GitHub")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("关于")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.11))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
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
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(icon: icon, color: iconColor)
            Text(title)
                .foregroundColor(.white)
            Spacer()
            content()
        }
    }
}

// MARK: - 语音选择视图
struct VoiceSelectionView: View {
    @Environment(AppState.self) var appState
    @State private var selectedVoiceId: String = ""
    
    var body: some View {
        List(appState.ttsService.availableVoices, id: \.identifier) { voice in
            HStack {
                VStack(alignment: .leading) {
                    Text(voice.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(voice.language)
                        .font(.caption)
                        .foregroundColor(.gray)
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
            .listRowBackground(Color(white: 0.11))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("选择语音")
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            selectedVoiceId = appState.ttsService.selectedVoice?.identifier ?? ""
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
