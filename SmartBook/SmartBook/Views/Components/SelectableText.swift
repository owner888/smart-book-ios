//
//  SelectableText.swift
//  SmartBook
//
//  可选择的文本视图 - 使用UITextView实现真正的文本选择
//

import SwiftUI
import UIKit

// MARK: - Selectable Text View
struct SelectableText: UIViewRepresentable {
    let attributedText: NSAttributedString
    var textColor: UIColor = .white
    var backgroundColor: UIColor = .clear

    func makeUIView(context: Context) -> CustomTextView {
        let textView = CustomTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = .link

        // 确保文本视图可以换行和调整大小
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)  // 允许水平压缩（换行）
        textView.setContentCompressionResistancePriority(.required, for: .vertical)

        return textView
    }

    func updateUIView(_ uiView: CustomTextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.backgroundColor = backgroundColor
        // 强制重新计算尺寸
        uiView.invalidateIntrinsicContentSize()
    }
}

// MARK: - Custom TextView with proper sizing
class CustomTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        // 计算文本的实际大小
        let textSize = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: textSize.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

// MARK: - 便捷初始化器
extension SelectableText {
    init(text: String, font: UIFont = .systemFont(ofSize: 15), textColor: UIColor = .white) {
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
            ]
        )
        self.attributedText = attributed
        self.textColor = textColor
    }
}
