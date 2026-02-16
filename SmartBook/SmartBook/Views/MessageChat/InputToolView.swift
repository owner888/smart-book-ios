//
//  InputToolView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/7.
//  Modified on 2026/2/15 - 使用 SwiftUI 替代 XIB
//

import Combine
import SwiftUI
import UIKit

class InputToolView: UIView {
    // MARK: - Properties
    
    var viewModel: ChatViewModel?
    var aiFunction = MenuConfig.AIModelFunctionType.auto {
        didSet {
            updateSwiftUIView()
        }
    }
    var assistant = MenuConfig.AssistantType.chat {
        didSet {
            updateSwiftUIView()
        }
    }
    var send: (() -> Void)?
    var showPopover: ((MessagePopoverAction, UIView) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    // SwiftUI Hosting Controller
    private var hostingController: UIHostingController<AnyView>?
    
    // 用于 popover 定位的临时视图
    private var anchorView = UIView()
    
    // 高度约束（用于动态调整）
    private var heightConstraint: NSLayoutConstraint?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }
    
    // MARK: - Setup
    
    func setUp() {
        // SwiftUI 内容已有边框和背景，UIKit 容器不需要边框
        layer.masksToBounds = false
        layer.cornerRadius = 0
        backgroundColor = .clear
        
        // 添加锚点视图用于 popover 定位
        anchorView.backgroundColor = .clear
        addSubview(anchorView)
        
        // 设置 SwiftUI 视图
        setupSwiftUIView()
    }
    
    // MARK: - SwiftUI Integration
    
    private func setupSwiftUIView() {
        guard let viewModel = viewModel else { return }
        
        // 创建 SwiftUI 视图（添加 fixedSize 让它自适应高度）
        let swiftUIView = createSwiftUIView()
            .fixedSize(horizontal: false, vertical: true)
        
        // 创建 HostingController
        let hosting = UIHostingController(rootView: AnyView(swiftUIView))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加到视图层级
        addSubview(hosting.view)
        
        // 设置约束，但不固定高度
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        hostingController = hosting
        
        // 让容器根据内容调整大小
        invalidateIntrinsicContentSize()
    }
    
    private func createSwiftUIView() -> some View {
        guard let viewModel = viewModel else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            InputToolContentView(
                viewModel: viewModel,
                aiFunction: Binding(
                    get: { [weak self] in
                        self?.aiFunction ?? .auto
                    },
                    set: { [weak self] newValue in
                        self?.aiFunction = newValue
                    }
                ),
                assistant: Binding(
                    get: { [weak self] in
                        self?.assistant ?? .chat
                    },
                    set: { [weak self] newValue in
                        self?.assistant = newValue
                    }
                ),
                inputText: Binding(
                    get: { [weak self] in
                        self?.viewModel?.inputText ?? ""
                    },
                    set: { [weak self] newValue in
                        self?.viewModel?.inputText = newValue
                    }
                ),
                openMedia: { [weak self] rect in
                    self?.openMedia(at: rect)
                },
                openModel: { [weak self] rect in
                    self?.changeModel(at: rect)
                },
                openAssistant: { [weak self] rect in
                    self?.changeAssistant(at: rect)
                },
                onSend: { [weak self] in
                    self?.sendMessage()
                },
                onHeightChanged: { [weak self] in
                    // 高度变化时更新布局
                    self?.invalidateIntrinsicContentSize()
                    self?.superview?.setNeedsLayout()
                    UIView.animate(withDuration: 0.3) {
                        self?.superview?.layoutIfNeeded()
                    }
                }
            )
        )
    }
    
    private func updateSwiftUIView() {
        hostingController?.rootView = AnyView(createSwiftUIView())
        
        // 强制更新高度
        DispatchQueue.main.async { [weak self] in
            self?.invalidateIntrinsicContentSize()
            self?.superview?.setNeedsLayout()
            self?.superview?.layoutIfNeeded()
        }
    }
    
    // MARK: - Bindings
    
    func bind(to model: ChatViewModel) {
        self.viewModel = model
        
        // 重新设置 SwiftUI 视图
        setupSwiftUIView()
        
        // ✅ 不再订阅 $inputText 和 $mediaItems 来触发 updateSwiftUIView()
        // InputToolContentView 内部通过 @ObservedObject viewModel 自动监听这些 @Published 属性
        // 之前每次输入字符都会重建整棵 SwiftUI 视图树，造成不必要的性能开销
        // aiFunction / assistant 等结构性变化通过 didSet → updateSwiftUIView() 处理
    }
    
    // MARK: - Actions
    
    private func openMedia(at rect: CGRect) {
        // 将 SwiftUI 的 CGRect 转换为 UIKit 坐标
        updateAnchorView(with: rect)
        showPopover?(.openMedia, anchorView)
    }
    
    private func changeModel(at rect: CGRect) {
        updateAnchorView(with: rect)
        showPopover?(.chooseModel, anchorView)
    }
    
    private func changeAssistant(at rect: CGRect) {
        updateAnchorView(with: rect)
        showPopover?(.assistant, anchorView)
    }
    
    private func sendMessage() {
        send?()
    }
    
    private func updateAnchorView(with rect: CGRect) {
        // 将全局坐标转换为当前视图的局部坐标
        let localRect = convert(rect, from: nil)
        anchorView.frame = localRect
    }
    
    // MARK: - Layout
    
    override var intrinsicContentSize: CGSize {
        // 让容器根据 SwiftUI 内容的实际大小调整
        guard let hostingView = hostingController?.view else {
            return CGSize(width: UIView.noIntrinsicMetric, height: 100)
        }
        
        let targetSize = CGSize(width: bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width,
                               height: UIView.layoutFittingExpandedSize.height)
        let size = hostingView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        return CGSize(width: UIView.noIntrinsicMetric, height: max(size.height, 100))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // SwiftUI 内容自己处理边框，UIKit 容器不需要
    }
}
