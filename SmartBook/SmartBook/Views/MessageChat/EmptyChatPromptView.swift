//
//  EmptyChatPromptView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/11.
//

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
        var config = UIButton.Configuration.filled()
        config.title = L("chat.emptyState.addBook")
        config.image = UIImage(systemName: "plus.circle.fill")
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(
            self,
            action: #selector(addBookButtonTapped),
            for: .touchUpInside
        )
        return button
    }()

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

    private func applyColors() {
        let primaryText = UIColor(colors.primaryText)
        let secondaryText = UIColor(colors.secondaryText)

        iconImageView.tintColor = secondaryText.withAlphaComponent(0.6)
        titleLabel.textColor = primaryText
        descriptionLabel.textColor = secondaryText
        addBookButton.configuration?.baseForegroundColor = primaryText

        // 应用液态玻璃按钮样式
        applyGlassButtonStyle(to: addBookButton)
    }

    private func applyGlassButtonStyle(to button: UIButton) {
        let isPressed = button.state == .highlighted
        let opacity: CGFloat = isPressed ? 0.08 : 0.05
        let borderOpacity: CGFloat = isPressed ? 0.2 : 0.25
        let innerBorderOpacity: CGFloat = isPressed ? 0.05 : 0.08
        let shadowOpacity: CGFloat = isPressed ? 0.08 : 0.12
        let shadowRadius: CGFloat = isPressed ? 8 : 12
        let shadowY: CGFloat = isPressed ? 2 : 4

        button.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 1

        // 渐变边框
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = button.bounds
        gradientLayer.cornerRadius = 22
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(borderOpacity).cgColor,
            UIColor.white.withAlphaComponent(innerBorderOpacity).cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: shadowY)
        button.layer.shadowRadius = shadowRadius
        button.layer.shadowOpacity = Float(shadowOpacity)

        button.transform =
            isPressed ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
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
        // 更新按钮渐变层
        let button = addBookButton
        applyGlassButtonStyle(to: button)
    }
}
