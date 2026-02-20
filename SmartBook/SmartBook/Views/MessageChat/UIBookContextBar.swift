//
//  UIBookContextBar.swift
//  SmartBook
//
//  参考 SwiftUI BookContextBar 实现
//

import SwiftUI
import UIKit

/// 书籍上下文栏 - 选择书籍后显示在聊天顶部
final class UIBookContextBar: UIView {

    // MARK: - Properties

    private var onClear: (() -> Void)?
    private let themeManager = ThemeManager.shared

    // MARK: - UI Components

    private lazy var bookIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "book.fill")
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var clearButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        return button
    }()

    private lazy var clearBackground: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(bookIcon)
        addSubview(titleLabel)
        addSubview(clearBackground)
        clearBackground.addSubview(clearButton)

        NSLayoutConstraint.activate([
            // 整体高度
            heightAnchor.constraint(equalToConstant: 40),

            // 书籍图标
            bookIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bookIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            bookIcon.widthAnchor.constraint(equalToConstant: 16),
            bookIcon.heightAnchor.constraint(equalToConstant: 16),

            // 标题
            titleLabel.leadingAnchor.constraint(equalTo: bookIcon.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: clearBackground.leadingAnchor, constant: -8),

            // 关闭按钮背景圆圈
            clearBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            clearBackground.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearBackground.widthAnchor.constraint(equalToConstant: 24),
            clearBackground.heightAnchor.constraint(equalToConstant: 24),

            // 关闭按钮
            clearButton.centerXAnchor.constraint(equalTo: clearBackground.centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: clearBackground.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 24),
            clearButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    // MARK: - Configuration

    func configure(book: Book, onClear: @escaping () -> Void) {
        self.onClear = onClear
        titleLabel.text = String(format: L("chat.readingBook"), book.title)
        applyColors()
    }

    // MARK: - Theming

    private func applyColors() {
        let colorScheme: ColorScheme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
        let colors = themeManager.colors(for: colorScheme)

        backgroundColor = UIColor(colors.cardBackground)
        titleLabel.textColor = UIColor(colors.primaryText).withAlphaComponent(0.8)
        clearButton.tintColor = UIColor(colors.secondaryText)
        clearBackground.backgroundColor = UIColor(colors.secondaryText).withAlphaComponent(0.15)
    }

    // MARK: - Actions

    @objc private func clearTapped() {
        onClear?()
    }

    // MARK: - Trait Collection

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyColors()
        }
    }
}
