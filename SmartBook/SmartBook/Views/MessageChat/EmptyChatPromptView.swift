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
        // ✅ iOS 26+ 使用系统玻璃效果，否则用 filled
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .filled()
        }

        config.title = L("chat.emptyState.addBook")
        config.image = UIImage(systemName: "plus.circle.fill")
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        // ✅ 调整按钮大小 - 更大更舒适
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)

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
        addBookButton.configuration?.baseForegroundColor = .white
        
        // ✅ 使用与 Create Videos 相同的背景色
        addBookButton.configuration?.baseBackgroundColor = .clear
        
        // iOS 26+ 使用 .glass() 配置，iOS 25- 需要手动玻璃样式
        if #unavailable(iOS 26.0) {
            applyGlassButtonStyle(to: addBookButton)
        }
    }
    
    // iOS 25 及以下的手动玻璃效果
    private func applyGlassButtonStyle(to button: UIButton) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        // ✅ 根据主题模式选择背景色
        if isDarkMode {
            // 深色模式：apprBlack 10% 透明度
            button.backgroundColor = UIColor.apprBlack.withAlphaComponent(0.1)
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        } else {
            // 浅色模式：apprWhite 15% 透明度
            button.backgroundColor = UIColor.apprWhite.withAlphaComponent(0.15)
            button.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
        }
        
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 1
        
        // 微妙阴影
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 12
        button.layer.shadowOpacity = isDarkMode ? 0.12 : 0.08
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
