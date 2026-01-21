//
//  ConversationModel.swift
//  SmartBook
//
//  Created by kaka on 20/1/26.
//

import SwiftData
import Foundation

@Model
class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var messages: [Message] = []

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
    }
}
