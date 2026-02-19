//
//  MessageChatViewViewWrapper.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/7.
//

import SwiftUI

struct MessageChatViewViewWrapper: UIViewRepresentable {
    let viewModel: ChatViewModel
    @Binding var aiFunction: MenuConfig.AIModelFunctionType
    @Binding var assistant: MenuConfig.AssistantType
    var hasBooks: Bool = false
    let action: (MessageChatAction) -> Void
    
    func makeUIView(context: Context) -> MessageChatView {
        let view = MessageChatView()
        view.bind(to: viewModel)
        view.action = action
        view.hasBooks = hasBooks
        view.aiFunction = aiFunction
        view.assistant = assistant
        return view
    }
    
    func updateUIView(_ uiView: MessageChatView, context: Context) {
        uiView.hasBooks = hasBooks
        uiView.aiFunction = aiFunction
        uiView.assistant = assistant
    }
}
