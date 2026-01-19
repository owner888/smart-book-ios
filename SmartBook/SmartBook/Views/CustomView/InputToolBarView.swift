//
//  InputToolBarView.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/17.
//

import SwiftUI

struct InputToolBarView<Content: View>: View {
    @Binding var inputText: String
    @ViewBuilder var content: Content
    var onSend: (() -> Void)?  // 新增：发送回调
    var keyboardHeightChanged: ((CGFloat) -> Void)?
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
                    VStack(spacing:0) {
                        if !hiddenTopView {
                            InputTopView { function in

                            }
                        }

                        InputToolBar(
                            aiFunction: $aiFunction,
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
                            onSend: {
                                hiddenTopView = true
                                // 传递发送回调
                                onSend?()
                            }
                        )
                    }.padding(.horizontal,18)

                }.padding(.bottom,keyboardHeight)
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
                    ).environmentObject(menuObser)
                }
                if showModelMenu {
                    CustomMenuView(alignment: .bottomLeading, edgeInsets: modelMenuEdge)
                    {
                        AIFunctionMenu(currentFunc: $aiFunction) { function in
                            aiFunction = function
                            menuObser.close()
                        }
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

struct MediaMenu: View {
    var onSelected: (MenuConfig.MediaMenuType) -> Void
    private let configs = MenuConfig.medias
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                ForEach(0..<3, id:\.self) { i in
                    menuItem(configs[i])
                }
            }
            Color.apprBlack.opacity(0.15).frame(height: 0.5).padding(.horizontal,12).padding(.vertical,5)
            VStack(spacing:4) {
                ForEach(3..<5,id:\.self) { i in
                    menuItem(configs[i])
                }
            }
        }.padding(.vertical,6).frame(width: 176)
        
    }
    
    func menuItem(_ type: MenuConfig.MediaMenuType) -> some View {
        Button {
            onSelected(type)
        } label: {
            HStack(spacing: 15) {
                Color.apprBlack.frame(width: 32,height: 32).opacity(0.08).clipShape(RoundedRectangle(cornerRadius:16)).overlay {
                    MenuIcon(config: type.config)
                }
                Text(type.config.title).font(.headline).foregroundStyle(Color.apprBlack)
                Spacer()
            }.padding(.horizontal,12).padding(.vertical,6).contentShape(Rectangle())
            
        }
    }
}

struct AIFunctionMenu: View {
    @Binding var currentFunc: MenuConfig.AIModelFunctionType
    var action: (MenuConfig.AIModelFunctionType) -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 3) {
                upgradeView
                Color.apprBlack.frame(height: 0.5).opacity(0.15).padding(.horizontal,12)
                ForEach(0..<MenuConfig.aiFunctions.count,id:\.self, content: { i in
                    menuItem(MenuConfig.aiFunctions[i])
                })
            }.padding(.all,6)
        }.frame(height: 332)
    }
    
    var upgradeView: some View {
        let config = MenuConfig.AIModelFunctionType.super.config
        return Button {
            action(.super)
        } label: {
            HStack(spacing:12) {
                VStack(alignment:.leading, spacing: 6) {
                    HStack(spacing:6) {
                        MenuIcon(config: config,size: 20)
                        Text(config.title).font(.title3).bold().foregroundStyle(.apprBlack).opacity(0.8)
                    }
                    Text(config.summary ?? "").font(.caption).foregroundStyle(.apprBlack).opacity(0.3)
                }
                Text("升级").font(.headline).foregroundStyle(.apprWhite).padding(.horizontal,12).padding(.vertical,8).background {
                    Color.apprBlack.clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }.padding(.horizontal,12).padding(.vertical,8).contentShape(Rectangle())
        }
    }
    
    func menuItem(_ type: MenuConfig.AIModelFunctionType) -> some View {
        let config = type.config
        let isSelected = type == currentFunc
        return Button {
            action(type)
        } label: {
            HStack(spacing:12) {
              MenuIcon(config: config)
                VStack(alignment:.leading, spacing: 5) {
                    Text(config.title).foregroundStyle(.apprBlack).opacity(0.8)
                    Text(config.summary ?? "").font(.caption).foregroundStyle(.apprBlack).opacity(0.5)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").resizable().scaledToFit().foregroundStyle(.apprBlack).frame(width: 16,height: 16)
                }
                
            }.padding(.all,12).background {
                if isSelected {
                    Color.apprBlack.opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Color.white.opacity(0.001)
                }
                
            }
        }.buttonStyle(MenuButtonStyle())
    }
    
    
}

struct MenuIcon: View {
    
    var config: MenuConfig.Config
    var size: CGFloat = 14
    var color: Color = Color.apprBlack
    
    var body: some View {
        Group {
            if config.builtIn {
                Image(systemName: config.icon).resizable().scaledToFit()
            } else {
                Image(config.icon).resizable().renderingMode(.template).scaledToFit()
            }
        }.frame(width: size,height: size).foregroundStyle(color)
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


struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

class MenuConfig {
    static let medias: [MediaMenuType] = [.camera,.photo,.file,.createPhoto,.editPhoto]
    static let aiFunctions: [AIModelFunctionType] = [.heavy,.expert,.fast,.auto,.thinking]
    static let topFunctions: [TopFunctionType] = [.getSuper, .createVideo,.editPhoto,.voiceMode,.camera,.analysisDocument,.custom]
    
    struct Config {
        var icon: String
        var title: String
        var summary: String? = nil
        var builtIn: Bool = true //icon是否内置
    }
    
    enum MediaMenuType {
        case camera
        case photo
        case file
        case createPhoto
        case editPhoto
        
        var config: Config {
            switch self {
            case .camera:
                return Config(icon: "camera", title: "摄像头")
            case .photo:
                return Config(icon: "photo.on.rectangle.angled", title: "照片")
            case .file:
                return Config(icon: "document", title: "文件")
            case .createPhoto:
                return Config(icon: "photo.badge.plus", title: "创作图片")
            case .editPhoto:
                return Config(icon: "square.and.pencil", title: "编辑图像")
            }
        }
    }
    
    enum AIModelFunctionType {
        case `super`
        case heavy
        case expert
        case fast
        case auto
        case thinking
        
        var config: Config {
            switch self {
            case .super:
                return Config(icon: "bolt.circle", title: "SuperGrok",summary: "解锁全部功能")
            case .heavy:
                return Config(icon: "square.grid.2x2", title: "Heavy",summary: "Team of experts")
            case .expert:
                return Config(icon: "lightbulb.max", title: "Expert",summary: "Thinks hard")
            case .fast:
                return Config(icon: "bolt", title: "Fast",summary: "Quick responses by 4.1")
            case .auto:
                return Config(icon: "airplane", title: "Auto", summary: "Chooses Fast or Expert")
            case .thinking:
                return Config(icon: "moon", title: "Grok 4.1 Thinking", summary: "Thinks fast")
            }
            
        }
    }
    
    enum TopFunctionType {
        case getSuper
        case createVideo
        case editPhoto
        case voiceMode
        case camera
        case analysisDocument
        case custom
        
        var config: Config {
            switch self {
            case .getSuper:
                return Config(icon: "bolt.circle", title: "SuperGrok")
            case .createVideo:
                return Config(icon: "photo.badge.plus", title: "创建视频")
            case .editPhoto:
                return Config(icon: "square.and.pencil", title: "编辑图像")
            case .voiceMode:
                return Config(icon: "waveform", title: "语音模式")
            case .camera:
                return Config(icon: "camera", title: "打开相机")
            case .analysisDocument:
                return Config(icon: "document", title: "分析文档")
            case .custom:
                return Config(icon: "slider.horizontal.3", title: "自定义 Grok")
            }
        
        }
    }
}
