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
    @Environment(AssistantService.self) private var assistantService
    @State private var themeManager = ThemeManager.shared
    @State private var beforeAdaptationBottom = 0.0

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
    
    // 媒体选择器状态
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var mediaItems: [MediaItem] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack {
                    VStack {
                        ZStack(alignment: .bottom) {
                            content
                            if !hiddenTopView {
                                InputTopView { function in
                                    // 处理顶部功能
                                }.padding(.bottom,6)
                            } else {
                                if viewModel.showScrollToBottom {
                                    HStack {
                                        Spacer()
                                        Button {
                                            viewModel.scrollToBottom()
                                        } label: {
                                            Color.white.opacity(0.001).frame(width: 42, height: 42).overlay {
                                                Image(systemName: "chevron.down")
                                                    .foregroundStyle(.apprBlack)
                                            }
                                        }.glassEffect(
                                            size: CGSize(width: 42, height: 42)
                                        )
                                    }.padding(.bottom, 2).padding(.trailing, 12)
                                }
                            }
                        }
                        InputToolBar(
                            viewModel: viewModel,
                            aiFunction: $aiFunction,
                            assistant: $assistant,
                            inputText: $inputText,
                            mediaItems: $mediaItems,
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
                    }.clipShape(Rectangle()).padding(.horizontal, 18)
                    if keyboardHeight == 0 {
                        Color.clear.frame(height: viewModel.safeAreaBottom)
                   }
                }.padding(.bottom, keyboardHeight)
                if showMediaMenu {
                    CustomMenuView(
                        alignment: .bottomLeading,
                        edgeInsets: mediaMenuEdge,
                        content: {
                            MediaMenu { type in
                                handleMediaSelection(type)
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
                                    // 同步切换 ModelService 的模型
                                    if let model = modelService.models.first(where: { $0.id == function.modelId }) {
                                        modelService.switchModel(model)
                                        Logger.debug("✅ Switched to model: \(model.id)")
                                    }
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
                                // 同步更新 AssistantService
                                updateAssistant(assistantType)
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
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera) { image in
                handleImagePicked(image)
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            if #available(iOS 14, *) {
                PhotoPicker(
                    onImagePicked: { image in
                        handleImagePicked(image)
                    },
                    onMultipleImagesPicked: { images in
                        handleMultipleImagesPicked(images)
                    },
                    selectionLimit: 10  // 最多选择10张
                )
            } else {
                ImagePicker(sourceType: .photoLibrary) { image in
                    handleImagePicked(image)
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(
                allowedTypes: DocumentPicker.allDocuments,
                onDocumentPicked: { url in
                    handleDocumentPicked(url)
                },
                onMultipleDocumentsPicked: { urls in
                    handleMultipleDocumentsPicked(urls)
                },
                allowsMultipleSelection: true  // 启用多选
            )
        }
        .onAppear {
            // 设置默认模型和助手
            updateAIFunction(from: modelService.currentModel.id)
            updateAssistantFromService()

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
        .onChange(of: assistantService.currentAssistant.id) { oldValue, newValue in
            // 监听助手变化，自动更新 UI
            updateAssistantFromService()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }

    // MARK: - Helper Methods
    
    private func handleMediaSelection(_ type: MenuConfig.MediaMenuType) {
        switch type {
        case .camera:
            // 检查相机权限
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCameraPicker = true
            } else {
                Logger.warning("⚠️ Camera not available")
            }
        case .photo:
            showPhotoPicker = true
        case .file:
            showDocumentPicker = true
        case .createPhoto, .editPhoto:
            // TODO: 实现图片创作和编辑功能
            Logger.info("📝 Feature coming soon: \(type.config.title)")
        }
    }
    
    private func handleImagePicked(_ image: UIImage) {
        let item = MediaItem(type: .image(image))
        mediaItems.append(item)
        Logger.info("✅ Image selected: \(image.size), total: \(mediaItems.count)")
    }
    
    private func handleMultipleImagesPicked(_ images: [UIImage]) {
        for image in images {
            let item = MediaItem(type: .image(image))
            mediaItems.append(item)
        }
        Logger.info("✅ \(images.count) images selected, total: \(mediaItems.count)")
    }
    
    private func handleDocumentPicked(_ url: URL) {
        let item = MediaItem(type: .document(url))
        mediaItems.append(item)
        Logger.info("✅ Document selected: \(url.lastPathComponent), total: \(mediaItems.count)")
    }
    
    private func handleMultipleDocumentsPicked(_ urls: [URL]) {
        for url in urls {
            let item = MediaItem(type: .document(url))
            mediaItems.append(item)
        }
        Logger.info("✅ \(urls.count) documents selected, total: \(mediaItems.count)")
    }

    private func updateAIFunction(from modelId: String) {
        if let matchingFunction = MenuConfig.aiFunctions.first(where: { $0.modelId == modelId }) {
            aiFunction = matchingFunction
            Logger.debug("✅ Set aiFunction from model: \(modelId) -> \(matchingFunction.config.title)")
        } else {
            Logger.warning("⚠️ No matching aiFunction found for model: \(modelId)")
        }
    }

    private func updateAssistant(_ assistantType: MenuConfig.AssistantType) {
        // 根据 AssistantType 查找对应的 Assistant
        if let matchingAssistant = assistantService.assistants.first(where: {
            switch assistantType {
            case .chat: return $0.id == "chat"
            case .ask: return $0.id == "ask"
            case .continue: return $0.id == "continue"
            case .dynamic(let dynamicAssistant): return $0.id == dynamicAssistant.id
            }
        }) {
            assistantService.switchItem(matchingAssistant)
            Logger.debug("✅ Switched to assistant: \(matchingAssistant.name)")
        }
    }

    private func updateAssistantFromService() {
        // 从 AssistantService 同步到本地 assistant 状态
        let currentAssistantId = assistantService.currentAssistant.id
        if let matchingType = MenuConfig.assistants.first(where: {
            switch $0 {
            case .chat: return currentAssistantId == "chat"
            case .ask: return currentAssistantId == "ask"
            case .continue: return currentAssistantId == "continue"
            case .dynamic(let dynamicAssistant): return currentAssistantId == dynamicAssistant.id
            }
        }) {
            assistant = matchingType
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
                    self.keyboardHeight = keyboardHeight
                    // 减去底部安全区域的高度
                    let bottomSafeArea = window.safeAreaInsets.bottom
                    let adjustedKeyboardHeight = max(
                        0,
                        keyboardHeight - bottomSafeArea
                    )
                    
                    keyboardHeightChanged?(adjustedKeyboardHeight)
                    viewModel.keyboardChanging = true
                    if viewModel.scrollBottom > adjustedKeyboardHeight {
                        viewModel.reducedScrollBottom = true
                        beforeAdaptationBottom = viewModel.scrollBottom
                        viewModel.scrollBottom -= adjustedKeyboardHeight
                    } else if !viewModel.showScrollToBottom {
                        if viewModel.scrollBottom > 20 {
                            viewModel.reducedScrollBottom = true
                            beforeAdaptationBottom = viewModel.scrollBottom
                            viewModel.scrollBottom = 20
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                        viewModel.keyboardChanging = false
                    })
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.keyboardChanging = true
            keyboardHeightChanged?(0)
            self.keyboardHeight = 0
            viewModel.keyboardChanging = true
            if viewModel.reducedScrollBottom {
                viewModel.scrollBottom = beforeAdaptationBottom
            }
            viewModel.reducedScrollBottom = false
//            if !viewModel.showScrollToBottom {
//                withAnimation(.easeIn(duration: 0.2)) {
//                    viewModel.scrollToBottom(animate: false)
//                }
//            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                viewModel.keyboardChanging = false
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
