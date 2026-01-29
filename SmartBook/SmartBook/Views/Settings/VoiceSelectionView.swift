// VoiceSelectionView.swift - 语音选择视图

import SwiftUI
internal import AVFAudio

struct VoiceSelectionView: View {
    @Environment(ThemeManager.self) var themeManager
    @EnvironmentObject var ttsService: TTSService
    @Environment(\.colorScheme) var systemColorScheme
    @State private var selectedVoiceId: String = ""
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        List(ttsService.availableVoices, id: \.identifier) { voice in
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
                ttsService.selectedVoice = voice
            }
            .listRowBackground(colors.cardBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle(L("voice.select"))
        .toolbarBackground(colors.navigationBar, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            selectedVoiceId = ttsService.selectedVoice?.identifier ?? ""
        }
    }
}
