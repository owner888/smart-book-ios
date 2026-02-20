//
//  UIMessageAssistantHeaderView.swift
//  SmartBook
//
//  Extracted from MessageDisplayView.swift
//

import SwiftUI
import UIKit

final class UIMessageAssistantHeaderView: UIView {
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let avatarCircle: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        addSubview(stackView)

        avatarCircle.addSubview(avatarLabel)
        stackView.addArrangedSubview(avatarCircle)
        stackView.addArrangedSubview(nameLabel)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarCircle.widthAnchor.constraint(equalToConstant: 24),
            avatarCircle.heightAnchor.constraint(equalToConstant: 24),

            avatarLabel.centerXAnchor.constraint(
                equalTo: avatarCircle.centerXAnchor
            ),
            avatarLabel.centerYAnchor.constraint(
                equalTo: avatarCircle.centerYAnchor
            ),
        ])
    }

    func configure(assistant: Assistant, colors: ThemeColors) {
        avatarCircle.backgroundColor = UIColor(assistant.colorValue)
            .withAlphaComponent(0.2)
        avatarLabel.text = assistant.avatar
        nameLabel.text = assistant.name
        nameLabel.textColor = UIColor(colors.secondaryText)
    }
}
