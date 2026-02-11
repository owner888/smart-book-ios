//
//  UserChatCell.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/9.
//

import UIKit
import SwiftUI

class UserChatCell: ChatCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    override func configure(_ message: ChatMessage, assistant: Assistant?, colors: ThemeColors) {
        super.configure(message, assistant: assistant, colors: colors)
        messageView.layer.masksToBounds = true
        messageView.layer.cornerRadius = 16
        messageView.backgroundColor = UIColor(colors.userBubble)
    }
    
}


