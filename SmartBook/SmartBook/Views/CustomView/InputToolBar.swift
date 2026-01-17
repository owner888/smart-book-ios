//
//  InputToolBar.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/16.
//

import SwiftUI

struct InputToolBar: View {
    @Binding var aiModel: String
    @Binding var inputText: String
    var openMedia: (CGRect) -> Void
    var openModel: (CGRect) -> Void

    @State private var isRecording = false
    @State private var mediaBtnFrame = CGRect.zero
    @State private var modelBtnFrame = CGRect.zero

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text("畅所欲问").font(.callout).foregroundStyle(Color.gray)
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
                    Color.clear.frame(width: 36,height: 36).overlay {
                        Image(systemName: "link").foregroundStyle(.apprBlack)
                    }
                }.glassEffect(size: CGSize(width: 36, height: 36))
                .getFrame($mediaBtnFrame)

                Button {
                    openModel(modelBtnFrame)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "airplane").resizable().frame(
                            width: 14,
                            height: 14
                        ).foregroundStyle(.apprBlack)
                        Text(aiModel).font(.caption2).foregroundStyle(.apprBlack)
                        Image(systemName: "chevron.down").resizable().frame(
                            width: 8,
                            height: 8
                        ).foregroundStyle(.apprBlack)
                    }.padding(.horizontal, 10).padding(.vertical, 6)
                }.glassEffect(cornerRadius: 15)
                .getFrame($modelBtnFrame)

                Spacer()
                Button {
                    isRecording = !isRecording
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isRecording ? "stop.fill" : "waveform").resizable().frame(
                            width: 12,
                            height: 12
                        ).foregroundStyle(.apprWhite)
                        Text(isRecording ? "停止" : "开始说话").font(.caption2).foregroundStyle(.apprWhite)
                    }.padding(.horizontal, 10).padding(.vertical, 6)
                }.background {
                    Color.apprBlack.clipShape(RoundedRectangle(cornerRadius: 12))
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
            }.padding(.horizontal,18).padding(.vertical,6)
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
