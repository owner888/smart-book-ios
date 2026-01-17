//
//  InputToolBarView.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/17.
//

import SwiftUI

struct InputToolBarView<Content: View>: View {
    @Binding var inputText: String
    @ViewBuilder var content: (_ keyboardHeight: CGFloat) -> Content
    var onSend: (() -> Void)?  // 新增：发送回调
    
    @State private var aiModel = "ChatGPT"
    @State private var keyboardHeight: CGFloat = 0
    @State private var mediaMenuEdge = EdgeInsets()
    @State private var modelMenuEdge = EdgeInsets()
    @State private var showMediaMenu = false
    @State private var showModelMenu = false
    @StateObject private var menuObser = CustomMenuObservable()

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                content(keyboardHeight)
                InputToolBar(
                    aiModel: $aiModel,
                    inputText: $inputText,
                    openMedia: { rect in
                        mediaMenuEdge = buttonRelatively(rect, proxy: proxy)
                        menuObser.willShow()
                        showMediaMenu = true

                    },
                    openModel: { rect in
                        modelMenuEdge = buttonRelatively(rect, proxy: proxy)
                        menuObser.willShow()
                        showModelMenu = true
                    },
                    onSend: onSend  // 传递发送回调
                ).offset(y: -keyboardHeight)
                    .ignoresSafeArea(.keyboard)
                if showMediaMenu {
                    CustomMenuView(
                        alignment: .bottomLeading,
                        edgeInsets: mediaMenuEdge,
                        content: {
                            mediaMenu
                        },
                        label: {
                            Color.clear.frame(width: 40, height: 40)
                        }
                    ).environmentObject(menuObser)
                }
                if showModelMenu {
                    CustomMenuView(alignment: .bottomLeading, edgeInsets: modelMenuEdge)
                    {
                        aiModelMenu
                    } label: {
                        Color.clear.frame(width: 60, height: 30)
                    }.environmentObject(menuObser)
                }
            }
        }.contentShape(Rectangle()).onTapGesture {
            hiddenKeyboard()
        }.onAppear {
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

    func buttonRelatively(_ rect: CGRect, proxy: GeometryProxy) -> EdgeInsets {
        var size = proxy.size
        size.height = size.height + proxy.safeAreaInsets.top
        return rect.edgeInset(size)
    }

    var mediaMenu: some View {
        VStack {
            ForEach(0..<5, id: \.self) { i in
                Button {
                    menuObser.close()
                } label: {
                    VStack {
                        Text("Media \(i)").padding(.vertical, 5)
                        if i != 4 {
                            Divider()
                        }
                    }
                }
            }
        }.padding(.horizontal, 12).frame(width: 160)
    }

    var aiModelMenu: some View {
        VStack {
            ForEach(0..<5, id: \.self) { i in
                Button {
                    menuObser.close()
                    aiModel = "AIModel \(i)"
                } label: {
                    VStack {
                        Text("AIModel \(i)").padding(.vertical, 5)
                        if i != 4 {
                            Divider()
                        }
                    }.padding(.horizontal, 20)
                }
            }
        }.padding(.horizontal, 12).frame(width: 160)
    }

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

extension View {
    func hiddenKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
