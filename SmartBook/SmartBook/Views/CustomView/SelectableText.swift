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
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = .link
        
        // 确保文本视图可以调整大小
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.backgroundColor = backgroundColor
    }
}

// MARK: - 便捷初始化器
extension SelectableText {
    init(text: String, font: UIFont = .systemFont(ofSize: 15), textColor: UIColor = .white) {
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor
            ]
        )
        self.attributedText = attributed
        self.textColor = textColor
    }
}
