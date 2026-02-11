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
    var onSend: (() -> Void)?
    var keyboardHeightChanged: ((CGFloat) -> Void)?

    @Environment(\.colorScheme) private var systemColorScheme

    @State private var themeManager = ThemeManager.shared

    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }

    @State private var showScrollToBottomButton = false
    @State private var aiFunction: MenuConfig.AIModelFunctionType = .auto
    @State private var assistant: MenuConfig.AssistantType = .chat
    @State private var mediaMenuEdge = EdgeInsets()
    @State private var modelMenuEdge = EdgeInsets()
    @State private var assistantMenuEdge = EdgeInsets()
    @State private var showMediaMenu = false
    @State private var showModelMenu = false
    @State private var showAssistantMenu = false
    @State private var hiddenTopView = false
    @State private var showVIPSheet = false
    // 媒体选择器状态
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false

    //@StateObject private var menuObser = CustomMenuObservable()
    @EnvironmentObject private var menuObser: CustomMenuObservable
    @State private var mediaItems: [MediaItem] = []

    var body: some View {

        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                // 输入框区域
                VStack(spacing: 0) {
                    // 顶部功能栏
                    if !hiddenTopView {
                        InputTopView { function in
                            // 处理顶部功能
                        }.padding(.bottom, 6)
                    } else {
                        // 滚动到底部按钮
                        if viewModel.showScrollToBottom {
                            HStack {
                                Spacer()
                                Button {
                                    viewModel.scrollToBottom()
                                } label: {
                                    Color.white.opacity(0.001).frame(
                                        width: 42,
                                        height: 42
                                    ).overlay {
                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(.apprBlack)
                                    }
                                }.glassEffect(
                                    size: CGSize(width: 42, height: 42)
                                )
                            }.padding(.bottom, 2).padding(.trailing, 12)
                        }
                    }

                    // 输入工具栏
                    InputToolBar(
                        viewModel: viewModel,
                        aiFunction: $aiFunction,
                        assistant: $assistant,
                        inputText: $inputText,
                        mediaItems: $viewModel.mediaItems,
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
                .background(colors.background)

                if showMediaMenu || showModelMenu || showAssistantMenu {
                    PopoverBgView(
                        showMediaMenu: $showMediaMenu,
                        mediaMenuEdge: $mediaMenuEdge,
                        showModelMenu: $showModelMenu,
                        modelMenuEdge: $modelMenuEdge,
                        showAssistantMenu: $showAssistantMenu,
                        assistantMenuEdge: $assistantMenuEdge,
                        aiFunction: $aiFunction,
                        assistant: $assistant,
                        mediaItems: $mediaItems,
                        showVIPSheet: $showVIPSheet,
                        showCameraPicker: $showCameraPicker,
                        showPhotoPicker: $showPhotoPicker,
                        showDocumentPicker: $showDocumentPicker
                    ).environmentObject(menuObser)
                }

            }
        }.modifier(
            MenuSheet(
                viewModel: viewModel,
                showVIPSheet: $showVIPSheet,
                showCameraPicker: $showCameraPicker,
                showPhotoPicker: $showPhotoPicker,
                showDocumentPicker: $showDocumentPicker,
                mediaItems: $mediaItems
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            hiddenKeyboard()
        }
    }

    func buttonRelatively(_ rect: CGRect, proxy: GeometryProxy) -> EdgeInsets {
        var size = proxy.size
        size.height = size.height + proxy.safeAreaInsets.top
        return rect.edgeInset(size)
    }
}

struct PopoverBgView: View {

    @Binding var showMediaMenu: Bool
    @Binding var mediaMenuEdge: EdgeInsets
    @Binding var showModelMenu: Bool
    @Binding var modelMenuEdge: EdgeInsets
    @Binding var showAssistantMenu: Bool
    @Binding var assistantMenuEdge: EdgeInsets
    @Binding var aiFunction: MenuConfig.AIModelFunctionType
    @Binding var assistant: MenuConfig.AssistantType
    @Binding var mediaItems: [MediaItem]

    @EnvironmentObject private var menuObser: CustomMenuObservable
    @Environment(AssistantService.self) private var assistantService
    @Environment(ModelService.self) private var modelService
    @Binding var showVIPSheet: Bool

    // 媒体选择器状态
    @Binding var showCameraPicker: Bool
    @Binding var showPhotoPicker: Bool
    @Binding var showDocumentPicker: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            // 菜单覆盖层
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
                    label: { Color.clear.frame(width: 40, height: 40) }
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
                                if let model = modelService.models.first(
                                    where: { $0.id == function.modelId })
                                {
                                    modelService.switchModel(model)
                                    Logger.debug(
                                        "✅ Switched to model: \(model.id)"
                                    )
                                }
                                menuObser.close()
                            },
                            onUpgrade: {
                                menuObser.close()
                                showVIPSheet = true
                            }
                        )
                    },
                    label: { Color.clear.frame(width: 60, height: 30) }
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
                            updateAssistant(assistantType)
                            menuObser.close()
                        }
                    },
                    label: { Color.clear.frame(width: 60, height: 30) }
                )
                .environmentObject(menuObser)
            }
        }.onAppear {
            menuObser.onClose = {
                if showMediaMenu {
                    showMediaMenu = false
                } else if showModelMenu {
                    showModelMenu = false
                } else if showAssistantMenu {
                    showAssistantMenu = false
                }
            }
        }
        .onChange(of: modelService.currentModel.id) { _, newValue in
            updateAIFunction(from: newValue)
        }
        .onChange(of: assistantService.currentAssistant.id) { _, _ in
            updateAssistantFromService()
        }
    }

    private func handleMediaSelection(_ type: MenuConfig.MediaMenuType) {
        switch type {
        case .camera:
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
            Logger.info("📝 Feature coming soon: \(type.config.title)")
        }
    }

    private func updateAIFunction(from modelId: String) {
        if let matchingFunction = MenuConfig.aiFunctions.first(where: {
            $0.modelId == modelId
        }) {
            aiFunction = matchingFunction
        } else {
            Logger.warning(
                "⚠️ No matching aiFunction found for model: \(modelId)"
            )
        }
    }

    private func updateAssistant(_ assistantType: MenuConfig.AssistantType) {
        if let matchingAssistant = assistantService.assistants.first(where: {
            switch assistantType {
            case .chat: return $0.id == "chat"
            case .ask: return $0.id == "ask"
            case .continue: return $0.id == "continue"
            case .dynamic(let dynamicAssistant):
                return $0.id == dynamicAssistant.id
            }
        }) {
            assistantService.switchItem(matchingAssistant)
        }
    }

    private func updateAssistantFromService() {
        let currentAssistantId = assistantService.currentAssistant.id
        if let matchingType = MenuConfig.assistants.first(where: {
            switch $0 {
            case .chat: return currentAssistantId == "chat"
            case .ask: return currentAssistantId == "ask"
            case .continue: return currentAssistantId == "continue"
            case .dynamic(let dynamicAssistant):
                return currentAssistantId == dynamicAssistant.id
            }
        }) {
            assistant = matchingType
        }
    }

}

struct MenuSheet: ViewModifier {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showVIPSheet: Bool

    // 媒体选择器状态
    @Binding var showCameraPicker: Bool
    @Binding var showPhotoPicker: Bool
    @Binding var showDocumentPicker: Bool
    @Binding var mediaItems: [MediaItem]

    func body(content: Content) -> some View {
        content.sheet(isPresented: $showVIPSheet) {
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
                    selectionLimit: 10
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
                allowsMultipleSelection: true
            )
        }
    }

    private func handleImagePicked(_ image: UIImage) {
        let item = MediaItem(type: .image(image))
        viewModel.mediaItems.append(item)
        Logger.info("✅ Image selected: \(image.size), total: \(viewModel.mediaItems.count)")
        Logger.info(
            "✅ Image selected: \(image.size), total: \(mediaItems.count)"
        )
    }

    private func handleMultipleImagesPicked(_ images: [UIImage]) {
        for image in images {
            let item = MediaItem(type: .image(image))
            viewModel.mediaItems.append(item)
        }
        Logger.info("✅ \(images.count) images selected, total: \(viewModel.mediaItems.count)")
    }

    private func handleDocumentPicked(_ url: URL) {
        let item = MediaItem(type: .document(url))
        viewModel.mediaItems.append(item)
        Logger.info("✅ Document selected: \(url.lastPathComponent), total: \(viewModel.mediaItems.count)")
    }

    private func handleMultipleDocumentsPicked(_ urls: [URL]) {
        for url in urls {
            let item = MediaItem(type: .document(url))
            viewModel.mediaItems.append(item)
        }
        Logger.info("✅ \(urls.count) documents selected, total: \(viewModel.mediaItems.count)")
    }

}
