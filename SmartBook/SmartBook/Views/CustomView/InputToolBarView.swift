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
    @Environment(ModelService.self) private var modelService
    @State private var themeManager = ThemeManager.shared
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }

    @State private var showScrollToBottomButton = false  // 控制按钮显示
    @State private var aiFunction: MenuConfig.AIModelFunctionType = .auto
    @State private var assistant: MenuConfig.AssistantType = .chat
    @State private var keyboardHeight: CGFloat = 0
    @State private var mediaMenuEdge = EdgeInsets()
    @State private var modelMenuEdge = EdgeInsets()
    @State private var assistantMenuEdge = EdgeInsets()
    @State private var showMediaMenu = false
    @State private var showModelMenu = false
    @State private var showAssistantMenu = false
    @State private var showVIPSheet = false
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
                                        viewModel.forceScrollToBottom = true
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
                            assistant: $assistant,
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
                            openAssistant: { rect in
                                assistantMenuEdge = buttonRelatively(
                                    rect,
                                    proxy: proxy
                                )
                                menuObser.willShow()
                                showAssistantMenu = true
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
                            AIFunctionMenu(
                                currentFunc: $aiFunction,
                                action: { function in
                                    aiFunction = function
                                    menuObser.close()
                                },
                                onUpgrade: {
                                    menuObser.close()
                                    showVIPSheet = true
                                }
                            )
                        },
                        label: {
                            Color.clear.frame(width: 60, height: 30)
                        }
                    )
                    .environmentObject(menuObser)
                }
                
                if showAssistantMenu {
                    CustomMenuView(
                        alignment: .bottomLeading,
                        edgeInsets: assistantMenuEdge,
                        content: {
                            AssistantMenu(currentAssistant: $assistant) {
                                assistantType in
                                assistant = assistantType
                                menuObser.close()
                            }
                        },
                        label: {
                            Color.clear.frame(width: 60, height: 30)
                        }
                    )
                    .environmentObject(menuObser)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hiddenKeyboard()
        }
        .sheet(isPresented: $showVIPSheet) {
            VIPUpgradeView()
        }
        .onAppear {
            // 设置默认模型
            updateAIFunction(from: modelService.currentModel.id)
            
            menuObser.onClose = {
                if showMediaMenu {
                    showMediaMenu = false
                } else if showModelMenu {
                    showModelMenu = false
                } else if showAssistantMenu {
                    showAssistantMenu = false
                }
            }
            setupKeyboardObservers()
        }
        .onChange(of: modelService.currentModel.id) { oldValue, newValue in
            // 监听模型变化，自动更新 aiFunction
            updateAIFunction(from: newValue)
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }

    // MARK: - Helper Methods
    
    private func updateAIFunction(from modelId: String) {
        if let matchingFunction = MenuConfig.aiFunctions.first(where: { $0.modelId == modelId }) {
            aiFunction = matchingFunction
            Logger.debug("✅ Set aiFunction from model: \(modelId) -> \(matchingFunction.config.title)")
        } else {
            Logger.warn("⚠️ No matching aiFunction found for model: \(modelId)")
        }
    }

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
                viewModel.isKeyboardChange = true
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    if !viewModel.showScrollToBottom && viewModel.forceScrollToBottom{
                        viewModel.scrollToBottom()
                    }
                    viewModel.isKeyboardChange = false
                    viewModel.showedKeyboard = true
                })
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.isKeyboardChange = true
            keyboardHeightChanged?(0)
            withAnimation(.easeOut(duration: 0.25)) {
                self.keyboardHeight = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                if !viewModel.showScrollToBottom && viewModel.forceScrollToBottom {
                    viewModel.scrollToBottom()
                }
                viewModel.isKeyboardChange = false
                viewModel.showedKeyboard = false
            })
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
