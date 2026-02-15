//
//  MessageChatCell.swift
//  SmartBook
//
//  SwiftUI 版本的消息 Cell
//  Created on 2026/2/15.
//

import SwiftUI
import UIKit

// MARK: - SwiftUI 消息 Cell
class SwiftUIMessageCell: UITableViewCell {
    static let identifier = "SwiftUIMessageCell"

    var onHeightChanged: ((ChatMessage?, CGFloat) -> Void)?
    private var message: ChatMessage?
    private var colors: ThemeColors = .dark

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
    }

    func configure(message: ChatMessage, colors: ThemeColors) {
        self.message = message
        self.colors = colors

        // 使用 iOS 16+ 的 UIHostingConfiguration
        if #available(iOS 16.0, *) {
            contentConfiguration = UIHostingConfiguration {
                MessageBubble(message: message, colors: colors)
            }
            .margins(.all, 0)
            .background(.clear)
        } else {
            // iOS 16 以下使用传统方法
            setupLegacyHosting(message: message, colors: colors)
        }

        // 监听高度变化
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let height = self.contentView.systemLayoutSizeFitting(
                CGSize(width: self.bounds.width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
            self.onHeightChanged?(self.message, height)
        }
    }

    // iOS 16 以下的降级方案
    private func setupLegacyHosting(message: ChatMessage, colors: ThemeColors) {
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let hostingController = UIHostingController(rootView: MessageBubble(message: message, colors: colors))
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}
