//
//  MessageModel.swift
//  SmartBook
//
//  Created by kaka on 20/1/26.
//
import SwiftData
import Foundation

@Model
class Message {
    var id: UUID = UUID()
    var role: Role?
    var content: String = ""
    var createdAt: Date = Date()

    var conversation: Conversation?

    init(
        role: Role,
        content: String,
        conversation: Conversation?
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.conversation = conversation
    }
}
