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
        layer.masksToBounds = false
        layer.cornerRadius = 22
        
        // ✅ 使用液态玻璃边框
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)
        
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
        
        model.$inputText.receive(on: DispatchQueue.main).sink {
            [weak self] _ in
            guard let self = self else { return }
            self.updateSwiftUIView()
        }.store(in: &cancellables)
        
        model.$mediaItems.receive(on: DispatchQueue.main).sink {
            [weak self] _ in
            guard let self = self else { return }
            self.updateSwiftUIView()
            self.layoutIfNeeded()
        }.store(in: &cancellables)
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
                               height: UIView.layoutFittingCompressedSize.height)
        let size = hostingView.systemLayoutSizeFitting(targetSize)
        
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // ✅ 更新玻璃边框
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)
    }
    
    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(
            comparedTo: previousTraitCollection
        ) {
            // ✅ 主题变化时更新边框
            let isDarkMode = traitCollection.userInterfaceStyle == .dark
            applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)
        }
    }
}
