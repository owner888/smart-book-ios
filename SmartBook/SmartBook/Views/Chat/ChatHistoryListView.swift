//
//  ChatHistoryListView.swift
//  SmartBook
//
//  Created by kaka on 26/1/26.
//

import SwiftData
import SwiftUI

/// 聊天历史列表视图
struct ChatHistoryListView: View {
    @ObservedObject var historyService: ChatHistoryService
    @ObservedObject var viewModel: ChatViewModel
    let colors: ThemeColors
    let onSelectConversation: () -> Void

    @State private var editingConversation: Conversation?
    @State private var showRenameAlert = false
    @State private var showDeleteAlert = false
    @State private var conversationToDelete: Conversation?
    @State private var newTitle = ""

    var body: some View {
        VStack(spacing: 0) {

            // 对话列表
            if historyService.conversations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 50))  // 装饰性大图标
                        .foregroundColor(colors.secondaryText)

                    Text(L("chatHistory.empty"))
                        .font(.subheadline)
                        .foregroundColor(colors.secondaryText)

                    Button(action: {
                        viewModel.startNewConversation()
                        onSelectConversation()
                    }) {
                        Text(L("chatHistory.startNew"))
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(colors.accentColor)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(historyService.conversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: historyService.currentConversation?.id == conversation.id,
                                colors: colors,
                                onTap: {
                                    viewModel.switchToConversation(conversation)
                                    onSelectConversation()
                                },
                                onRename: {
                                    editingConversation = conversation
                                    newTitle = conversation.title
                                    showRenameAlert = true
                                },
                                onDelete: {
                                    conversationToDelete = conversation
                                    showDeleteAlert = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(colors.background)
        .alert(L("chatHistory.rename.title"), isPresented: $showRenameAlert) {
            TextField(L("chatHistory.rename.placeholder"), text: $newTitle)
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("common.confirm")) {
                if let conversation = editingConversation {
                    historyService.renameConversation(conversation, newTitle: newTitle)
                }
            }
        }
        .alert(L("chatHistory.delete.title"), isPresented: $showDeleteAlert) {
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("common.delete"), role: .destructive) {
                if let conversation = conversationToDelete {
                    historyService.deleteConversation(conversation)
                }
            }
        } message: {
            Text(L("chatHistory.delete.message"))
        }
    }
}

/// 单个对话行
struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let colors: ThemeColors
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.subheadline)
                .foregroundColor(colors.primaryText)
                .lineLimit(1)

            HStack(spacing: 4) {
                if let bookTitle = conversation.bookTitle {
                    Text(bookTitle)
                        .font(.caption2)
                        .foregroundColor(colors.secondaryText)
                        .lineLimit(1)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(colors.secondaryText)
                }

                Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? colors.sidebarCardBackground : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(action: onRename) {
                Label(L("chatHistory.menu.rename"), systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label(L("chatHistory.menu.delete"), systemImage: "trash")
            }
        }
    }
}
