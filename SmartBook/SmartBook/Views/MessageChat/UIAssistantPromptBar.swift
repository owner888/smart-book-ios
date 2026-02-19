//
//  UIAssistantPromptBar.swift
//  SmartBook
//
//  参考 SwiftUI AssistantPromptBar 实现
//

import SwiftUI
import UIKit

/// 助手系统提示词栏 - 显示在书籍上下文栏下方
final class UIAssistantPromptBar: UIView {

    // MARK: - Properties

    private var isExpanded = false
    private let themeManager = ThemeManager.shared
    private var assistantColor: UIColor = .systemGreen


    // MARK: - UI Components

    private lazy var headerButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(toggleExpanded), for: .touchUpInside)
        return button
    }()

    private lazy var avatarLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var chevronImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 10)
        let iv = UIImageView(image: UIImage(systemName: "chevron.down", withConfiguration: config))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var headerStack: UIStackView = {
        let spacer = UIView()
        let stack = UIStackView(arrangedSubviews: [avatarLabel, nameLabel, spacer, chevronImageView])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        return stack
    }()

    private lazy var divider: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var promptLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 折叠时：底部 = headerButton 底部（固定 36pt）
    private var collapsedBottomConstraint: NSLayoutConstraint!
    /// 展开时：底部 = promptLabel 底部 + 8pt
    private var expandedBottomConstraint: NSLayoutConstraint!

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true

        addSubview(headerButton)
        addSubview(headerStack)
        addSubview(divider)
        addSubview(promptLabel)

        // 折叠时底部约束：self.bottom = headerButton.bottom
        collapsedBottomConstraint = bottomAnchor.constraint(equalTo: headerButton.bottomAnchor)
        // 展开时底部约束：self.bottom = promptLabel.bottom + 8
        expandedBottomConstraint = bottomAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 8)

        // 初始状态：折叠
        collapsedBottomConstraint.isActive = true
        expandedBottomConstraint.isActive = false

        // 初始隐藏展开部分
        divider.alpha = 0
        promptLabel.alpha = 0

        NSLayoutConstraint.activate([
            headerButton.topAnchor.constraint(equalTo: topAnchor),
            headerButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerButton.heightAnchor.constraint(equalToConstant: 36),

            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            headerStack.heightAnchor.constraint(equalToConstant: 20),

            divider.topAnchor.constraint(equalTo: headerButton.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            promptLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8),
            promptLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            promptLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Configuration

    func configure(assistant: Assistant) {
        avatarLabel.text = assistant.avatar
        nameLabel.text = assistant.name
        promptLabel.text = assistant.systemPrompt
        assistantColor = UIColor(Color(hex: assistant.color) ?? .green)
        applyColors()
    }

    // MARK: - Theming

    private func applyColors() {
        let colorScheme: ColorScheme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
        let colors = themeManager.colors(for: colorScheme)

        backgroundColor = assistantColor.withAlphaComponent(0.1)
        nameLabel.textColor = UIColor(colors.primaryText).withAlphaComponent(0.9)
        chevronImageView.tintColor = UIColor(colors.secondaryText)
        divider.backgroundColor = UIColor(colors.secondaryText).withAlphaComponent(0.2)
        promptLabel.textColor = UIColor(colors.secondaryText)
    }

    // MARK: - Actions

    @objc private func toggleExpanded() {
        isExpanded.toggle()

        let config = UIImage.SymbolConfiguration(pointSize: 10)
        let imageName = isExpanded ? "chevron.up" : "chevron.down"
        chevronImageView.image = UIImage(systemName: imageName, withConfiguration: config)

        if isExpanded {
            collapsedBottomConstraint.isActive = false
            expandedBottomConstraint.isActive = true
        } else {
            expandedBottomConstraint.isActive = false
            collapsedBottomConstraint.isActive = true
        }

        // tableView.top 直接约束到 headerStack.bottom，Auto Layout 自动跟随高度变化
        UIView.animate(withDuration: 0.25) {
            self.divider.alpha = self.isExpanded ? 1 : 0
            self.promptLabel.alpha = self.isExpanded ? 1 : 0
            // 让整个视图层级重新布局（headerStack → tableView 约束链自动生效）
            self.superview?.superview?.layoutIfNeeded()
        }
    }

    // MARK: - Trait Collection

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyColors()
        }
    }
}
