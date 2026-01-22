//
//  InputToolBar.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/16.
//

import SwiftUI

struct InputToolBar: View {
    @Binding var aiFunction: MenuConfig.AIModelFunctionType
    @Binding var inputText: String
    var openMedia: (CGRect) -> Void
    var openModel: (CGRect) -> Void
    var onSend: (() -> Void)?  // 新增：发送回调


    @State private var isRecording = false
    @State private var mediaBtnFrame = CGRect.zero
    @State private var modelBtnFrame = CGRect.zero

    
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

            HStack(spacing: 16) {
                Button {
                    openMedia(mediaBtnFrame)
                } label: {
                    Color.clear.frame(width: 32,height: 32).overlay {
                        Image(systemName: "link").foregroundStyle(.apprBlack)
                    }
                }.glassEffect(size: CGSize(width: 32, height: 32))
                .getFrame($mediaBtnFrame)

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
                
                // 根据输入内容动态切换按钮
                if hasInput {
                    // 发送按钮
                    Button {
                        onSend?()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.circle.fill").resizable().frame(
                                width: 16,
                                height: 16
                            ).foregroundStyle(.apprWhite)
                            Text(L("chat.send")).font(.caption2).foregroundStyle(.apprWhite)
                        }.padding(.horizontal, 10).padding(.vertical, 6)
                    }.background {
                        Color.green.clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // 语音输入按钮
                    Button {
                        isRecording = !isRecording
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
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }.padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                GaussianBlurView().opacity(0.9).clipShape(RoundedRectangle(cornerRadius: 20))
            }.overlay {
                RoundedRectangle(cornerRadius: 20).stroke(
                    .gray.opacity(0.3),
                    lineWidth: 1
                )
            }.padding(.vertical,6)
            .animation(.spring(duration: 0.3), value: hasInput)  // 添加动画
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
