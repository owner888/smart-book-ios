// SettingsView.swift - 设置视图

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("apiBaseURL") private var apiBaseURL = "http://localhost:8080"
    @AppStorage("autoTTS") private var autoTTS = true
    @AppStorage("ttsRate") private var ttsRate = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                List {
                    // 服务器设置
                    Section {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.blue)
                            TextField("API 地址", text: $apiBaseURL)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }
                    } header: {
                        Text("服务器")
                    }
                    
                    // 语音设置
                    Section {
                        Toggle(isOn: $autoTTS) {
                            Label("自动朗读 AI 回复", systemImage: "speaker.wave.2")
                        }
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Label("语速", systemImage: "speedometer")
                                Spacer()
                                Text(String(format: "%.1fx", ttsRate))
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $ttsRate, in: 0.5...2.0, step: 0.1)
                        }
                        
                        // 语音选择
                        NavigationLink {
                            VoiceSelectionView()
                        } label: {
                            Label("选择语音", systemImage: "waveform")
                        }
                    } header: {
                        Text("语音")
                    }
                    
                    // 关于
                    Section {
                        HStack {
                            Label("版本", systemImage: "info.circle")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.gray)
                        }
                        
                        Link(destination: URL(string: "https://github.com")!) {
                            Label("GitHub", systemImage: "link")
                        }
                    } header: {
                        Text("关于")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("设置")
        }
        .onChange(of: ttsRate) { _, newValue in
            appState.ttsService.rate = Float(newValue)
        }
    }
}

// MARK: - 语音选择视图
struct VoiceSelectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedVoiceId: String = ""
    
    var body: some View {
        List(appState.ttsService.availableVoices, id: \.identifier) { voice in
            HStack {
                VStack(alignment: .leading) {
                    Text(voice.name)
                        .font(.headline)
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
        }
        .navigationTitle("选择语音")
        .onAppear {
            selectedVoiceId = appState.ttsService.selectedVoice?.identifier ?? ""
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
