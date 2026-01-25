//
//  ChatHistoryListView.swift
//  SmartBook
//
//  Created by kaka on 26/1/26.
//

import SwiftUI
import SwiftData

/// 聊天历史列表视图
struct ChatHistoryListView: View {
    @ObservedObject var historyService: ChatHistoryService
    @ObservedObject var viewModel: ChatViewModel
    let colors: ThemeColors
    let onSelectConversation: () -> Void
    
    @State private var editingConversation: Conversation?
    @State private var showRenameAlert = false
    @State private var newTitle = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("聊天历史")
                    .font(.headline)
                    .foregroundColor(colors.primaryText)
                
                Spacer()
                
                Button(action: {
                    viewModel.startNewConversation()
                    onSelectConversation()
                }) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(colors.accentColor)
                }
            }
            .padding()
            
            Divider()
                .background(colors.secondaryText.opacity(0.3))
            
            // 对话列表
            if historyService.conversations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 50))
                        .foregroundColor(colors.secondaryText)
                    
                    Text("暂无历史对话")
                        .font(.subheadline)
                        .foregroundColor(colors.secondaryText)
                    
                    Button(action: {
                        viewModel.startNewConversation()
                        onSelectConversation()
                    }) {
                        Text("开始新对话")
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
                                    historyService.deleteConversation(conversation)
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
        .alert("重命名对话", isPresented: $showRenameAlert) {
            TextField("对话标题", text: $newTitle)
            Button("取消", role: .cancel) { }
            Button("确定") {
                if let conversation = editingConversation {
                    historyService.renameConversation(conversation, newTitle: newTitle)
                }
            }
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
        HStack(spacing: 12) {
            // 图标
            Image(systemName: conversation.bookId != nil ? "book.fill" : "message")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : colors.secondaryText)
                .frame(width: 20)
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : colors.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if let bookTitle = conversation.bookTitle {
                        Text(bookTitle)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : colors.secondaryText)
                            .lineLimit(1)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.6) : colors.secondaryText)
                    }
                    
                    Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : colors.secondaryText)
                }
            }
            
            Spacer()
            
            // 菜单
            Menu {
                Button(action: onRename) {
                    Label("重命名", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(isSelected ? .white.opacity(0.8) : colors.secondaryText)
                    .padding(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? colors.accentColor : colors.cardBackground)
        .cornerRadius(8)
        .onTapGesture(perform: onTap)
    }
}
