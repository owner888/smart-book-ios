//
//  CommonChatCell.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/9.
//  Refactored: XIB → pure code
//

import UIKit

// ✅ 纯代码实现，不再依赖 CommonChatCell.xib
class CommonChatCell: UITableViewCell {
    
    let messageView = MessageDisplayView(frame: .zero)
    
    var onChangedSized: ((ChatMessage?, CGFloat) -> Void)? {
        didSet {
            messageView.onChangedSized = onChangedSized
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUp()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }
    
    private func setUp() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        messageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageView)
        
        NSLayoutConstraint.activate([
            messageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            messageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            messageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            messageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }
    
    func configure(_ message: ChatMessage, assistant: Assistant?, colors: ThemeColors) {
        messageView.config(message, assistant: assistant, colors: colors)
    }
}
