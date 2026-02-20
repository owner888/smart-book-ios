//
//  MessageInputTopView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/10.
//

import SwiftUI
import UIKit

class MessageInputTopView: UIView {

    // MARK: - Properties
    private let space: CGFloat = 50
    private var scrollWidth: CGFloat = 0
    private var contentWidth: CGFloat = 0
    private var scrollOffset: CGFloat = 0
    var function: ((MenuConfig.TopFunctionType) -> Void)?

    private var colors: ThemeColors {
        let colorScheme =
            traitCollection.userInterfaceStyle == .dark
            ? ColorScheme.dark : .light
        return themeManager.colors(for: colorScheme)
    }

    private var colorScheme: UIUserInterfaceStyle {
        traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    private let themeManager = ThemeManager.shared

    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var leftSpacer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var rightSpacer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var buttonViews: [UIButton] = []

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup
    private func setupUI() {
        // ✅ iOS 17+ 使用 registerForTraitChanges 替代 traitCollectionDidChange
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
            (self: MessageInputTopView, _: UITraitCollection) in
            self.updateAppearance()
        }

        addSubview(scrollView)
        scrollView.addSubview(leftSpacer)
        scrollView.addSubview(stackView)
        scrollView.addSubview(rightSpacer)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            leftSpacer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            leftSpacer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            leftSpacer.widthAnchor.constraint(equalToConstant: space),
            leftSpacer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            rightSpacer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            rightSpacer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            rightSpacer.widthAnchor.constraint(equalToConstant: space),
            rightSpacer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leftSpacer.trailingAnchor),
            stackView.trailingAnchor.constraint(equalTo: rightSpacer.leadingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        scrollView.delegate = self
        scrollView.contentOffset = CGPoint(x: space, y: 0)
        setupButtons()
    }

    private func setupButtons() {
        let functions = MenuConfig.topFunctions

        for function in functions {
            let button = createButton(for: function)
            stackView.addArrangedSubview(button)
            buttonViews.append(button)
        }
    }

    private func createButton(for type: MenuConfig.TopFunctionType) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = MenuConfig.topFunctions.firstIndex(of: type) ?? 0
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)

        let isGet = type == .getSuper

        // 容器视图（用于玻璃效果背景）
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 22
        containerView.clipsToBounds = true
        containerView.backgroundColor = UIColor((isGet ? colors.accentColor : .apprBlack)).withAlphaComponent(0.1)

        // 图标
        let iconView = MenuIconView(
            config: type.config,
            size: 18,
            color: UIColor(isGet ? colors.accentColor : .apprBlack)
        )
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.alpha = isGet ? 1 : 0.6

        // 标题
        let titleLabel = UILabel()
        titleLabel.text = type.config.title
        titleLabel.textColor = UIColor(isGet ? colors.accentColor : .apprBlack)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 添加到容器
        containerView.addSubview(iconView)
        containerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14),
        ])

        // 使用包装视图作为按钮的内容
        button.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: button.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        // iOS 18+ 玻璃效果
        if #available(iOS 18.0, *) {
            if isGet {
                let glassEffect = UIBlurEffect(style: .systemMaterial)
                let glassView = UIVisualEffectView(effect: glassEffect)
                glassEffectView = glassView
            }
        }

        return button
    }

    private var glassEffectView: UIVisualEffectView?

    // MARK: - Actions
    @objc private func buttonTapped(_ sender: UIButton) {
        let functions = MenuConfig.topFunctions
        guard sender.tag < functions.count else { return }
        function?(functions[sender.tag])
    }

    private func updateAppearance() {
        buttonViews.forEach { button in
            if let container = button.subviews.first {
                let isGet = button.tag == 0  // 假设第一个是 getSuper
                container.backgroundColor = UIColor((isGet ? colors.accentColor : .apprBlack)).withAlphaComponent(0.1)
            }
            if let titleLabel = button.subviews.first?.subviews.last as? UILabel {
                let isGet = button.tag == 0
                titleLabel.textColor = UIColor(isGet ? colors.accentColor : .apprBlack)
            }
        }
    }
}

// MARK: - UIScrollViewDelegate
extension MessageInputTopView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollOffset = scrollView.contentOffset.x

        // 左侧边界
        if scrollOffset < space {
            scrollView.setContentOffset(CGPoint(x: space, y: 0), animated: false)
        }

        // 右侧边界
        let maxOffset = contentWidth - scrollWidth - space
        if maxOffset > 0 && scrollOffset > maxOffset {
            scrollView.setContentOffset(CGPoint(x: maxOffset, y: 0), animated: false)
        }
    }
}

class MenuIconView: UIView {

    // MARK: - Properties
    private var config: MenuConfig.Config?
    private var size: CGFloat = 14
    private var color: UIColor = UIColor.apprBlack

    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    // MARK: - Init
    init(config: MenuConfig.Config, size: CGFloat = 14, color: UIColor = .apprBlack) {
        self.config = config
        self.size = size
        self.color = color
        super.init(frame: .zero)
        setupUI()
        updateSize()
    }

    func configure(_ config: MenuConfig.Config, size: CGFloat) {
        self.config = config
        self.size = size
        updateSize()
        updateImage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func updateSize() {
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
        ])
    }

    // MARK: - Setup
    private func setupUI() {
        // ✅ iOS 17+ 使用 registerForTraitChanges 替代 traitCollectionDidChange
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
            (self: MenuIconView, _: UITraitCollection) in
            self.updateImage()
        }

        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 1),
        ])
        updateImage()
    }

    private func updateImage() {
        guard let config = config else { return }
        let imageName: String
        if config.builtIn {
            // 系统 SF Symbols
            imageName = config.icon
        } else {
            // 自定义图片（假设在 Assets 中）
            imageName = config.icon
        }

        var image: UIImage?
        if let uiImage = UIImage(named: imageName) {
            image = uiImage
        } else if let sfImage = UIImage(systemName: imageName) {
            image = sfImage
        }

        if let image = image {
            imageView.image = image
            // 自定义图片需要 template 渲染模式
            if !config.builtIn {
                imageView.tintColor = color
            } else {
                imageView.tintColor = color
            }
        }
    }

    // MARK: - Public
    func update(config: MenuConfig.Config, color: UIColor) {
        self.config = config
        self.color = color
        updateImage()
    }

}
