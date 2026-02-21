//
//  EmptyChatPromptView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/11.
//

import Combine
import SwiftUI
import UIKit

/// 空状态视图 - 没有书籍时显示
final class UIEmptyStateView: UIView {

    // MARK: - Properties

    var colors: ThemeColors = .dark {
        didSet {
            applyColors()
        }
    }
    private var onAddBook: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var isDefaultChatAssistant: Bool = false  // ✅ 是否为默认 Chat 助手
    private var hasBooks: Bool = false  // ✅ 是否已有书籍（参考 SwiftUI: bookState.books.isEmpty）
    private var hasSelectedBook: Bool = false  // ✅ 是否已选择书籍

    // MARK: - UI Components

    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "books.vertical")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .gray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("chat.emptyState.title")
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = L("chat.emptyState.desc")
        label.font = .systemFont(ofSize: 17)
        label.textAlignment = .center
        label.numberOfLines = 0  // 无限行，自动换行
        label.lineBreakMode = .byWordWrapping  // ✅ 按单词换行
        label.preferredMaxLayoutWidth = UIScreen.main.bounds.width - 64 - 64  // ✅ 设置最大宽度：屏幕宽度 - stackView 边距 - descriptionLabel 边距
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var addBookButton: UIButton = {
        // ✅ 使用扩展创建液态玻璃按钮
        return UIButton.glassButton(
            title: L("chat.emptyState.addBook"),
            icon: "plus.circle.fill",
            target: self,
            action: #selector(addBookButtonTapped)
        )
    }()

    // 使用 UIStackView 进行布局
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            iconImageView, titleLabel, descriptionLabel, addBookButton,
        ])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

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
        addSubview(stackView)

        // ✅ iOS 17+ 使用 registerForTraitChanges 替代 traitCollectionDidChange
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
            (self: UIEmptyStateView, previousTraitCollection: UITraitCollection) in
            let colorScheme =
                self.traitCollection.userInterfaceStyle == .dark
                ? ColorScheme.dark : .light
            self.colors = ThemeManager.shared.colors(for: colorScheme)
            self.applyColors()
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 20
            ),
            stackView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -20
            ),
            stackView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -20
            ),

            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64),

            descriptionLabel.leadingAnchor.constraint(
                equalTo: stackView.leadingAnchor,
                constant: 32  // ✅ 和 SwiftUI 一致，左右各 32pt
            ),
            descriptionLabel.trailingAnchor.constraint(
                equalTo: stackView.trailingAnchor,
                constant: -32  // ✅ 和 SwiftUI 一致
            ),

        ])
    }

    // MARK: - Configuration

    func configure(
        colors: ThemeColors,
        hasBooks: Bool,
        onAddBook: @escaping () -> Void,
        isDefaultChatAssistant: Bool = false,
        hasSelectedBook: Bool = false
    ) {
        self.colors = colors
        self.hasBooks = hasBooks
        self.onAddBook = onAddBook
        self.isDefaultChatAssistant = isDefaultChatAssistant
        self.hasSelectedBook = hasSelectedBook

        if isDefaultChatAssistant {
            // ✅ Chat 助手：始终显示空聊天图标，无需选择书籍即可对话
            iconImageView.image = UIImage(systemName: "bubble.left.and.bubble.right")
            titleLabel.isHidden = true
            descriptionLabel.isHidden = true
            addBookButton.isHidden = true
        } else if hasSelectedBook {
            // ✅ 已选择书籍：显示聊天图标，隐藏按钮
            iconImageView.image = UIImage(systemName: "bubble.left.and.bubble.right")
            titleLabel.isHidden = true
            descriptionLabel.isHidden = true
            addBookButton.isHidden = true
        } else if hasBooks {
            // ✅ 有书籍但未选择：显示"选择书籍"（参考 SwiftUI EmptyChatStateView）
            iconImageView.image = UIImage(systemName: "bubble.left.and.bubble.right")
            titleLabel.text = L("chat.emptyState.noBookTitle")
            titleLabel.isHidden = false
            descriptionLabel.text = L("chat.emptyState.noBookDesc")
            descriptionLabel.isHidden = false
            // 按钮显示"选择书籍"
            addBookButton.configuration?.title = L("chat.menu.selectBook")
            addBookButton.configuration?.image = UIImage(systemName: "book")
            addBookButton.isHidden = false
        } else {
            // ✅ 没有书籍：显示"导入书籍"（参考 SwiftUI EmptyStateView）
            iconImageView.image = UIImage(systemName: "books.vertical")
            titleLabel.text = L("chat.emptyState.title")
            titleLabel.isHidden = false
            descriptionLabel.text = L("chat.emptyState.desc")
            descriptionLabel.isHidden = false
            // 按钮显示"添加书籍"
            addBookButton.configuration?.title = L("chat.emptyState.addBook")
            addBookButton.configuration?.image = UIImage(systemName: "plus.circle.fill")
            addBookButton.isHidden = false
        }

        applyColors()
    }

    // MARK: - Theming

    private func applyColors() {
        let primaryText = UIColor(colors.primaryText)
        let secondaryText = UIColor(colors.secondaryText)
        let isDarkMode = traitCollection.userInterfaceStyle == .dark

        iconImageView.tintColor = secondaryText.withAlphaComponent(0.6)
        titleLabel.textColor = primaryText
        descriptionLabel.textColor = secondaryText

        // ✅ 使用扩展应用玻璃效果
        addBookButton.configuration?.baseForegroundColor = isDarkMode ? .white : .black
        addBookButton.configuration?.baseBackgroundColor = .clear
        addBookButton.applyGlassEffect(isDarkMode: isDarkMode)
    }

    // MARK: - Actions

    @objc private func addBookButtonTapped() {
        onAddBook?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // ✅ 更新按钮玻璃效果
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        addBookButton.applyGlassEffect(isDarkMode: isDarkMode)
    }
}
