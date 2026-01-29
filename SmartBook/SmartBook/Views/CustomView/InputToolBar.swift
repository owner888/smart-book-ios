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
    @State private var isConnecting = false  // 新增：连接中状态
    @State private var mediaBtnFrame = CGRect.zero
    @State private var modelBtnFrame = CGRect.zero
    @State private var assistantBtnFrame = CGRect.zero
    
    // 语音识别服务
    @StateObject private var speechService = SpeechService()
    @StateObject private var asrStreamService = ASRStreamService()
    
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
                            // 根据状态显示不同图标
                            if isConnecting {
                                // 连接中显示转圈圈的 icon
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(.apprWhite)
                                    .rotationEffect(.degrees(isConnecting ? 360 : 0))
                                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isConnecting)
                                Text(L("chat.voice.start")).font(.caption2).foregroundStyle(.apprWhite)
                            } else {
                                Image(systemName: isRecording ? "stop.fill" : "waveform")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(.apprWhite)
                                Text(isRecording ? L("chat.voice.stop") : L("chat.voice.start")).font(.caption2).foregroundStyle(.apprWhite)
                            }
                        }.padding(.horizontal, 10).padding(.vertical, 6)
                    }.background {
                        Color.apprBlack.clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isConnecting)  // 连接中禁用按钮
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
        // 根据配置选择语音识别服务
        switch asrProvider {
        case "native":
            isRecording = true  // iOS 原生立即更新状态
            
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
            
        default:
            // 使用 Deepgram 流式识别（实时断句）
            Task {
                // 显示连接中状态
                isConnecting = true
                
                // 如果未连接，先连接
                if !asrStreamService.isConnected {
                    await asrStreamService.connect()
                }
                
                // 开始录音和流式识别
                // 等待 Deepgram 就绪后才更新按钮状态
                await asrStreamService.startRecording(
                    onDeepgramReady: { @MainActor in
                        // Deepgram 连接成功，开始接收音频
                        isConnecting = false  // 取消连接中状态
                        isRecording = true    // 开始录音状态
                        Logger.info("✅ Deepgram 就绪，开始录音")
                    },
                    onTranscriptUpdate: { [weak asrStreamService] text, isFinal in
                        inputText = text
                        
                        // 最终结果时自动停止并发送
                        if isFinal {
                            // 停止录音和断开连接
                            Task { @MainActor in
                                isRecording = false
                                await asrStreamService?.stopRecording()
                                await asrStreamService?.disconnect()
                                
                                // 自动发送消息
                                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    // 延迟一点，确保清理完成
                                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                                    onSend?()
                                }
                            }
                        }
                    }
                )
            }
            Logger.info("🎙️ 使用 Deepgram 流式识别（等待就绪 + 实时断句 + 自动发送）")
        }
    }
    
    private func stopRecording() {
        isRecording = false
        
        // 停止对应的语音识别服务
        switch asrProvider {
        case "native":
            speechService.stopRecording()
        default:
            Task {
                // 停止录音和断开 WebSocket 连接
                await asrStreamService.stopRecording()
                await asrStreamService.disconnect()
            }
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
