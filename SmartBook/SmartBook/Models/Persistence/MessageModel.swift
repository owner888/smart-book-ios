//
//  MessageModel.swift
//  SmartBook
//
//  Created by kaka on 20/1/26.
//
import SwiftData
import Foundation

@Model
class MessageModel {
    var id: UUID
    var role: Role
    var content: String
    var createdAt: Date

    var conversation: ConversationModel?

    init(
        role: Role,
        content: String,
        conversation: ConversationModel?
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = .now
        self.conversation = conversation
    }
}
