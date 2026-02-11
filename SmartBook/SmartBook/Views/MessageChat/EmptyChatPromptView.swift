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
        label.numberOfLines = 0
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
                constant: 12
            ),
            descriptionLabel.trailingAnchor.constraint(
                equalTo: stackView.trailingAnchor,
                constant: -12
            ),

        ])
    }

    // MARK: - Configuration

    func configure(colors: ThemeColors, onAddBook: @escaping () -> Void) {
        self.colors = colors
        self.onAddBook = onAddBook
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

    // MARK: - Trait Collection

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(
            comparedTo: previousTraitCollection
        ) {
            let colorScheme =
                traitCollection.userInterfaceStyle == .dark
                ? ColorScheme.dark : .light
            colors = ThemeManager.shared.colors(for: colorScheme)
            applyColors()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // ✅ 更新按钮玻璃效果
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        addBookButton.applyGlassEffect(isDarkMode: isDarkMode)
    }
}
