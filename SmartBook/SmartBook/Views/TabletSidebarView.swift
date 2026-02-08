// TabletSidebarView.swift - 平板端侧边栏视图（iPad/macOS专用，Journal风格）

import SwiftUI

// MARK: - 平板端侧边栏视图
struct TabletSidebarView: View {
    var colors: ThemeColors
    var historyService: ChatHistoryService?
    var viewModel: ChatViewModel?
    var onSelectChat: () -> Void
    var onSelectBookshelf: () -> Void
    var onSelectSettings: () -> Void
    
    @State private var isConversationsExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App 标题
            HStack {
                Image(systemName: "book.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                Text(L("app.name"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding()
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 可滚动内容区域
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Conversations 可折叠部分
                    VStack(alignment: .leading, spacing: 0) {
                        // 标题栏
                        Button(action: {
                            withAnimation {
                                isConversationsExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Text("Conversations")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                
                                Spacer()
                                
                                Image(systemName: isConversationsExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        
                        // 对话列表
                        if isConversationsExpanded {
                            if let historyService = historyService, let viewModel = viewModel {
                                TabletChatHistoryListView(
                                    historyService: historyService,
                                    viewModel: viewModel,
                                    onSelectConversation: onSelectChat
                                )
                                .padding(.horizontal, 12)
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)
                }
            }
            
            // 底部固定区域
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // 底部菜单
                VStack(alignment: .leading, spacing: 4) {
                    // 书架
                    TabletSidebarItem(
                        icon: "book",
                        title: L("library.title"),
                        isSelected: false,
                        action: onSelectBookshelf
                    )
                    
                    // 设置
                    TabletSidebarItem(
                        icon: "gearshape",
                        title: L("settings.title"),
                        isSelected: false,
                        action: onSelectSettings
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                // 底部用户信息
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        
                        VStack(alignment: .leading) {
                            Text(L("user.name"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Text(L("app.description"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(
            Color(red: 0.1, green: 0.1, blue: 0.12)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Tablet 侧边栏菜单项
struct TabletSidebarItem: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .frame(width: 28)
                
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tablet 聊天历史列表
struct TabletChatHistoryListView: View {
    var historyService: ChatHistoryService
    var viewModel: ChatViewModel
    var onSelectConversation: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(historyService.conversations) { conversation in
                Button(action: {
                    viewModel.switchToConversation(conversation)
                    onSelectConversation()
                }) {
                    TabletConversationItem(
                        title: conversation.title,
                        count: conversation.messages?.count ?? 0,
                        isSelected: historyService.currentConversation?.id == conversation.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Tablet 对话列表项
struct TabletConversationItem: View {
    let title: String
    let count: Int
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 28)
            
            // 标题
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            Spacer()
            
            // 计数
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
        )
    }
}

// MARK: - 预览
#Preview {
    TabletSidebarView(
        colors: .light,
        historyService: nil,
        viewModel: nil,
        onSelectChat: {},
        onSelectBookshelf: {},
        onSelectSettings: {}
    )
    .frame(width: 320)
}
