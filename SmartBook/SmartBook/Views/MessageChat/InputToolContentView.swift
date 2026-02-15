//
//  InputToolContentView.swift
//  SmartBook
//
//  SwiftUI 版本的输入框内容视图（基于 InputToolBar.swift）
//  Created on 2026/2/15.
//

import SwiftUI

// MARK: - 主视图
struct InputToolContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var aiFunction: MenuConfig.AIModelFunctionType
    @Binding var assistant: MenuConfig.AssistantType
    @Binding var inputText: String
    
    // Callbacks
    var openMedia: (CGRect) -> Void
    var openModel: (CGRect) -> Void
    var openAssistant: (CGRect) -> Void
    var onSend: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppConfig.Keys.asrProvider) private var asrProvider = AppConfig.DefaultValues.asrProvider

    @State private var isRecording = false
    @State private var isConnecting = false
    @State private var mediaBtnFrame = CGRect.zero
    @State private var modelBtnFrame = CGRect.zero
    @State private var assistantBtnFrame = CGRect.zero

    // 语音识别服务
    @StateObject private var speechService = SpeechService()
    @StateObject private var asrStreamService = ASRStreamService()

    // 判断是否有输入内容（文本或媒体）
    private var hasInput: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.mediaItems.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 媒体预览容器（支持多选和水平滚动）
            if !viewModel.mediaItems.isEmpty {
                MediaPreviewContainer(items: viewModel.mediaItems) { item in
                    // 记录删除日志
                    switch item.type {
                    case .image:
                        Logger.info("🗑️ Image removed, remaining: \(viewModel.mediaItems.count - 1)")
                    case .document(let url):
                        Logger.info("🗑️ Document removed: \(url.lastPathComponent), remaining: \(viewModel.mediaItems.count - 1)")
                    }
                    viewModel.mediaItems.removeAll { $0.id == item.id }
                }.padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 显示 ASR 状态消息（如果有）
            if let statusMessage = asrStreamService.statusMessage {
                HStack(spacing: 6) {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // 显示音频音量级别
                    if asrStreamService.isRecording && asrStreamService.audioLevel > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(
                                        asrStreamService.audioLevel > Float(index) * 0.2
                                            ? Color.green : Color.gray.opacity(0.3)
                                    )
                                    .frame(width: 2, height: CGFloat(4 + index * 2))
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 输入框
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

            // 底部按钮栏
            HStack(spacing: 8) {
                Button {
                    openMedia(mediaBtnFrame)
                } label: {
                    Color.clear.frame(width: 32, height: 32).overlay {
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

                // AI 回复中 → 显示 Stop 按钮
                if viewModel.isLoading {
                    Button {
                        viewModel.stopAnswer()
                    } label: {
                        Color.apprBlack.frame(width: 36, height: 36).overlay {
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
                                    .animation(
                                        .linear(duration: 1).repeatForever(autoreverses: false),
                                        value: isConnecting
                                    )
                                Text(L("chat.voice.start")).font(.caption2).foregroundStyle(.apprWhite)
                            } else {
                                Image(systemName: isRecording ? "stop.fill" : "waveform")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(.apprWhite)
                                Text(isRecording ? L("chat.voice.stop") : L("chat.voice.start")).font(.caption2)
                                    .foregroundStyle(.apprWhite)
                            }
                        }.padding(.horizontal, 10).padding(.vertical, 6)
                    }.background {
                        Color.apprBlack.clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isConnecting)
                    .padding(.trailing, -6)
                    .padding(.bottom, -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }.padding(.horizontal, 12)
            .padding(.vertical, 6)
            .animation(.spring(duration: 0.3), value: hasInput)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in }
            )
            .onAppear {
                // 视图加载时预连接 ASR 和 TTS（如果使用 Deepgram）
                if asrProvider != "native" {
                    Task {
                        // 延迟一点，避免阻塞 UI 初始化
                        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5秒

                        // 预连接 ASR
                        if !asrStreamService.isConnected {
                            await asrStreamService.connect()
                            Logger.info("🚀 Deepgram ASR 预连接完成")
                        }

                        // 预连接 TTS
                        if !viewModel.ttsStreamService.isConnected {
                            await viewModel.ttsStreamService.connect()
                            Logger.info("🚀 Deepgram TTS 预连接完成")
                        }

                        Logger.info("✅ ASR 和 TTS 都已就绪，随时可用")
                    }
                }
            }
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
            isRecording = true

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
            // 使用 Deepgram 流式识别
            Task {
                // 显示连接中状态
                isConnecting = true

                // 如果未连接，先连接
                if !asrStreamService.isConnected {
                    await asrStreamService.connect()
                }

                // 开始录音和流式识别
                asrStreamService.startRecording(
                    onDeepgramReady: { @MainActor in
                        isConnecting = false
                        isRecording = true
                        Logger.info("✅ Deepgram 就绪，开始录音")
                    },
                    onTranscriptUpdate: { [weak asrStreamService] text, isFinal in
                        inputText = text

                        // 最终结果时自动停止并发送
                        if isFinal {
                            Task { @MainActor in
                                isRecording = false
                                await asrStreamService?.stopRecording()

                                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmedText.count >= 2 {
                                    Logger.info("✅ 语音识别完成，自动发送: \(trimmedText)")

                                    try? await Task.sleep(nanoseconds: 100_000_000)

                                    await viewModel.sendMessage(trimmedText, enableTTS: true)
                                    inputText = ""
                                } else {
                                    Logger.warning("⚠️ 识别文本太短或为空，不自动发送: '\(trimmedText)'")
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
                await asrStreamService.stopRecording()
            }
        }

        Logger.info("🛑 停止录音（连接保持）")
    }
}
