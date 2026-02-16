//
//  UIMessageContentView.swift
//  SmartBook
//
//  Extracted from MessageDisplayView.swift
//

import SwiftUI
import UIKit

final class UIMessageContentView: UIView {
    var message: ChatMessage?
    var colors = ThemeColors.dark
    var textView: CustomTextView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    func setUp() {
        textView = CustomTextView()
        textView.font = .systemFont(ofSize: 14)  // 根据需要调整字体大小
        textView.isEditable = false  // 禁止编辑
        textView.isScrollEnabled = false  // 禁止滚动
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isSelectable = true  // 允许选择
        textView.delaysContentTouches = false
        textView.dataDetectorTypes = .link
        self.addSubview(textView)

        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func configure(_ message: ChatMessage, colors: ThemeColors) {
        self.message = message
        self.colors = colors
        if message.role == .user {
            textView.textColor = UIColor(colors.primaryText)
            textView.text = message.content
            textView.invalidateIntrinsicContentSize()
        } else {
            // 确保文本视图可以换行和调整大小
            textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            textView.setContentHuggingPriority(.required, for: .vertical)
            textView.setContentCompressionResistancePriority(
                .defaultLow,
                for: .horizontal
            )  // 允许水平压缩（换行）
            textView.setContentCompressionResistancePriority(
                .required,
                for: .vertical
            )

            let content = MessageDisplayContent(
                message: message,
                colors: colors
            )
            // 使用SelectableText实现真正的文本选择
            let attributedString = content.markdownToAttributedString()
            textView.attributedText = attributedString
            textView.invalidateIntrinsicContentSize()
        }
    }
}
