//
//  InputToolBar.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/16.
//

import SwiftUI

struct InputToolBar: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var aiFunction: MenuConfig.AIModelFunctionType
    @Binding var assistant: MenuConfig.AssistantType
    @Binding var inputText: String
    var openMedia: (CGRect) -> Void
    var openModel: (CGRect) -> Void
    var openAssistant: (CGRect) -> Void
    var onSend: (() -> Void)?  // 新增：发送回调

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppConfig.Keys.asrProvider) private var asrProvider = AppConfig.DefaultValues.asrProvider
    
    @State private var isRecording = false
    @State private var mediaBtnFrame = CGRect.zero
    @State private var modelBtnFrame = CGRect.zero
    @State private var assistantBtnFrame = CGRect.zero
    
    // 语音识别服务
    // 使用 @StateObject 确保实例在视图生命周期内保持不变，并自动响应状态变化
    @StateObject private var speechService = SpeechService()
    @StateObject private var asrService = ASRService()
    
    // 判断是否有输入内容
    private var hasInput: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text(L("chat.input.placeholder")).font(.callout).foregroundStyle(Color.gray)
                        .padding(.leading, 5)
                }
                TextEditor(text: $inputText).frame(
                    minHeight: 30,
                    maxHeight: 200
                )
                .fixedSize(horizontal: false, vertical: true)
                .scrollContentBackground(.hidden)
            }

            HStack(spacing: 8) {
                Button {
                    openMedia(mediaBtnFrame)
                } label: {
                    Color.clear.frame(width: 32,height: 32).overlay {
                        Image(systemName: "link").foregroundStyle(.apprBlack)
                    }
                }.glassEffect(size: CGSize(width: 32, height: 32))
                .getFrame($mediaBtnFrame)
                .padding(.leading, -6)

                Button {
                    openAssistant(assistantBtnFrame)
                } label: {
                    Color.clear.frame(width: 32, height: 32).overlay {
                        Text(assistant.config.icon).font(.title3)
                    }
                }.glassEffect(size: CGSize(width: 32, height: 32))
                .getFrame($assistantBtnFrame)

                Button {
                    openModel(modelBtnFrame)
                } label: {
                    HStack(spacing: 5) {
                        MenuIcon(config: aiFunction.config)
                        Text(aiFunction.config.title).font(.caption2).foregroundStyle(.apprBlack)
                        Image(systemName: "chevron.down").resizable().frame(
                            width: 8,
                            height: 8
                        ).foregroundStyle(.apprBlack)
                    }.padding(.horizontal, 10).frame(height: 32)
                }.glassEffect(cornerRadius: 15)
                .getFrame($modelBtnFrame)

                Spacer()
                
                if viewModel.isLoading {
                    Button {
                        viewModel.stopAnswer()
                    } label: {
                        Color.apprBlack.frame(width: 36,height: 36).overlay {
                            Image(systemName: "stop.fill").foregroundStyle(.apprWhite)
                        }.clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    // 根据输入内容动态切换按钮
                } else if hasInput {
                    // 发送按钮 - 正圆形，根据主题色切换
                    Button {
                        onSend?()
                    } label: {
                        Image(systemName: "arrow.up")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(colorScheme == .dark ? Color.apprWhite : Color.apprBlack)
                            .frame(width: 32, height: 32)
                            .background(colorScheme == .dark ? Color.apprBlack : Color.apprWhite)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, -6)
                    .padding(.bottom, -6)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // 语音输入按钮
                    Button {
                        toggleRecording()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isRecording ? "stop.fill" : "waveform").resizable().frame(
                                width: 12,
                                height: 12
                            ).foregroundStyle(.apprWhite)
                            Text(isRecording ? L("chat.voice.stop") : L("chat.voice.start")).font(.caption2).foregroundStyle(.apprWhite)
                        }.padding(.horizontal, 10).padding(.vertical, 6)
                    }.background {
                        Color.apprBlack.clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.trailing, -6)
                    .padding(.bottom, -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }.padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if #available(iOS 26, *) {
                    Color.clear.glassEffect(.regular,in: .rect(cornerRadius: 20))
                } else {
                    GaussianBlurView().opacity(0.9).clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
            }.overlay {
                RoundedRectangle(cornerRadius: 20).stroke(
                    .gray.opacity(0.3),
                    lineWidth: 1
                )
            }.padding(.vertical,6)
            .animation(.spring(duration: 0.3), value: hasInput)  // 添加动画
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in }
            )
    }
    
    // MARK: - 语音识别
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        // 根据配置选择语音识别服务
        switch asrProvider {
        case "native":
            // 使用 iOS 原生语音识别
            speechService.startRecording(
                onInterim: { text in
                    inputText = text
                },
                onFinal: { text in
                    inputText = text
                    isRecording = false
                }
            )
            Logger.info("🎤 使用 iOS 原生语音识别")
            
        case "google", "deepgram":
            // 使用后端 ASR 服务（Google/Deepgram）
            asrService.startRecording(
                onInterim: { text in
                    inputText = text
                },
                onFinal: { text in
                    inputText = text
                    isRecording = false
                }
            )
            Logger.info("🎤 使用后端 ASR 服务：\(asrProvider)")
            
        default:
            // 默认使用原生识别
            speechService.startRecording(
                onInterim: { text in
                    inputText = text
                },
                onFinal: { text in
                    inputText = text
                    isRecording = false
                }
            )
            Logger.info("🎤 使用 iOS 原生语音识别（默认）")
        }
    }
    
    private func stopRecording() {
        isRecording = false
        
        // 停止对应的语音识别服务
        switch asrProvider {
        case "native":
            speechService.stopRecording()
        case "google", "deepgram":
            asrService.stopRecording()
        default:
            speechService.stopRecording()
        }
        
        Logger.info("🛑 停止录音")
    }
}

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let newFrame = nextValue()
        if newFrame != .zero {
            value = newFrame
        }
    }
}

extension View {
    @ViewBuilder
    func getFrame(_ frame: Binding<CGRect>) -> some View {
        self.background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: FramePreferenceKey.self, value: proxy.frame(in: .global))
            }
        }
        .onPreferenceChange(FramePreferenceKey.self) { newFrame in
            frame.wrappedValue = newFrame
        }
    }
}
