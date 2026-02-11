//
//  CommonChatCell.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/9.
//

import UIKit

class CommonChatCell: ChatCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}

class ChatCell: UITableViewCell {
    @IBOutlet weak  var messageView: MessageDisplayView!
    
    var onChangedSized:((ChatMessage?,CGFloat) -> Void)? {
        didSet {
            messageView.onChangedSized = onChangedSized
        }
    }
    
    func configure(_ message: ChatMessage, assistant: Assistant?, colors: ThemeColors) {
        messageView.config(message, assistant: assistant, colors: colors)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = UIColor.clear
        contentView.backgroundColor = UIColor.clear
        selectionStyle = .none
    }
}
