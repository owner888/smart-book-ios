//
//  InputToolBarView.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/17.
//

import SwiftUI

struct InputToolBarView<Content: View>: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var inputText: String
    @ViewBuilder var content: Content
    var onSend: (() -> Void)?  // 发送回调
    var keyboardHeightChanged: ((CGFloat) -> Void)?

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var themeManager = ThemeManager.shared
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }

    @State private var showScrollToBottomButton = false  // 控制按钮显示
    @State private var aiFunction = MenuConfig.AIModelFunctionType.auto
    @State private var keyboardHeight: CGFloat = 0
    @State private var mediaMenuEdge = EdgeInsets()
    @State private var modelMenuEdge = EdgeInsets()
    @State private var showMediaMenu = false
    @State private var showModelMenu = false
    @State private var hiddenTopView = false
    @StateObject private var menuObser = CustomMenuObservable()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ZStack(alignment: .bottom) {
                    content
                    VStack(spacing: 0) {
                        if !hiddenTopView {
                            InputTopView { function in
                                // 处理顶部功能
                            }
                        } else {
                            if viewModel.showScrollToBottom {
                                HStack {
                                    Spacer()
                                    Button {
                                        viewModel.scrollToBottom()
                                    } label: {
                                        Color.white.opacity(0.001).frame(width: 42,height: 42).overlay {
                                            Image(systemName: "chevron.down")
                                                .foregroundStyle(.apprBlack)
                                        }
                                    }.glassEffect(
                                        size: CGSize(width: 42, height: 42)
                                    )
                                }.padding(.bottom,2).padding(.trailing, 12)
                            }
                        }

                        InputToolBar(
                            viewModel: viewModel,
                            aiFunction: $aiFunction,
                            inputText: $inputText,
                            openMedia: { rect in
                                mediaMenuEdge = buttonRelatively(
                                    rect,
                                    proxy: proxy
                                )
                                menuObser.willShow()
                                showMediaMenu = true
                            },
                            openModel: { rect in
                                modelMenuEdge = buttonRelatively(
                                    rect,
                                    proxy: proxy
                                )
                                menuObser.willShow()
                                showModelMenu = true
                            },
                            onSend: {
                                hiddenTopView = true
                                onSend?()
                            }
                        )
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.bottom, keyboardHeight)

                if showMediaMenu {
                    CustomMenuView(
                        alignment: .bottomLeading,
                        edgeInsets: mediaMenuEdge,
                        content: {
                            MediaMenu { type in
                                menuObser.close()
                            }
                        },
                        label: {
                            Color.clear.frame(width: 40, height: 40)
                        }
                    )
                    .environmentObject(menuObser)
                }

                if showModelMenu {
                    CustomMenuView(
                        alignment: .bottomLeading,
                        edgeInsets: modelMenuEdge,
                        content: {
                            AIFunctionMenu(currentFunc: $aiFunction) {
                                function in
                                aiFunction = function
                                menuObser.close()
                            }
                        },
                        label: {
                            Color.clear.frame(width: 60, height: 30)
                        }
                    )
                    .environmentObject(menuObser)
                }

                /*
                // 滚动到底部按钮 - 右下角悬浮
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            scrollToBottom?()
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(colors.accentColor.opacity(0.9))
                                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                )
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, keyboardHeight + 80)
                        .transition(.scale.combined(with: .opacity))
                    }
                }*/
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hiddenKeyboard()
        }
        .onAppear {
            menuObser.onClose = {
                if showMediaMenu {
                    showMediaMenu = false
                } else if showModelMenu {
                    showModelMenu = false
                }
            }
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }

    // MARK: - Helper Methods

    func buttonRelatively(_ rect: CGRect, proxy: GeometryProxy) -> EdgeInsets {
        var size = proxy.size
        size.height = size.height + proxy.safeAreaInsets.top
        return rect.edgeInset(size)
    }

    // MARK: - Keyboard Observers

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[
                UIResponder.keyboardFrameEndUserInfoKey
            ] as? CGRect {
                // 获取键盘在屏幕坐标系中的高度
                let window = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows
                    .first

                if let window = window {
                    let keyboardFrameInWindow = window.convert(
                        keyboardFrame,
                        from: UIScreen.main.coordinateSpace
                    )
                    let keyboardHeight =
                        window.bounds.height - keyboardFrameInWindow.origin.y

                    // 减去底部安全区域的高度
                    let bottomSafeArea = window.safeAreaInsets.bottom
                    let adjustedKeyboardHeight = max(
                        0,
                        keyboardHeight - bottomSafeArea
                    )
                    keyboardHeightChanged?(adjustedKeyboardHeight)
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.keyboardHeight = adjustedKeyboardHeight
                    }
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeightChanged?(0)
            withAnimation(.easeOut(duration: 0.25)) {
                self.keyboardHeight = 0
            }
        }
    }

    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
}
