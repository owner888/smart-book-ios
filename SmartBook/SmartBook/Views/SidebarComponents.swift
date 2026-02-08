// SidebarComponents.swift - 侧边栏公共组件

import SwiftUI

// MARK: - 侧边栏内容组件（公共逻辑）
struct SidebarContent: View {
    var colors: ThemeColors
    var historyService: ChatHistoryService?
    var viewModel: ChatViewModel?
    var onSelectChat: () -> Void
    var onSelectBookshelf: () -> Void
    var onSelectSettings: () -> Void
    var style: SidebarStyle
    
    @State private var isConversationsExpanded = true
    @State private var searchText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App 标题
            AppTitleView(style: style)
            
            SidebarDivider(style: style)
            
            // Library 菜单项
            MenuItemView(
                icon: "book",
                title: L("library.title"),
                isSelected: false,
                style: style,
                action: onSelectBookshelf
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            SidebarDivider(style: style)
            
                // 可滚动内容区域
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Conversations 可折叠部分
                        ConversationsSectionView(
                            historyService: historyService,
                            viewModel: viewModel,
                            onSelectChat: onSelectChat,
                            isExpanded: $isConversationsExpanded,
                            searchText: searchText,
                            style: style
                        )
                    }
                }
            
            // 底部固定搜索框和新建按钮
            SearchAndNewChatView(
                searchText: $searchText,
                viewModel: viewModel,
                onSelectChat: onSelectChat,
                style: style
            )
        }
        .background(style.backgroundColor.ignoresSafeArea())
    }
}

// MARK: - App 标题视图
struct AppTitleView: View {
    var style: SidebarStyle
    
    var body: some View {
        HStack {
            Image(systemName: "book.circle.fill")
                .font(.title)
                .foregroundColor(.green)
            Text(L("app.name"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(style.titleColor)
        }
        .padding()
    }
}

// MARK: - Conversations 部分
struct ConversationsSectionView: View {
    var historyService: ChatHistoryService?
    var viewModel: ChatViewModel?
    var onSelectChat: () -> Void
    @Binding var isExpanded: Bool
    var searchText: String
    var style: SidebarStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Conversations")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(style.sectionTitleColor)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(style.sectionTitleColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            // 对话列表
            if isExpanded {
                if let historyService = historyService, let viewModel = viewModel {
                    ConversationsListView(
                        historyService: historyService,
                        viewModel: viewModel,
                        searchText: searchText,
                        onSelectConversation: onSelectChat,
                        style: style
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - 对话列表
struct ConversationsListView: View {
    @ObservedObject var historyService: ChatHistoryService
    var viewModel: ChatViewModel
    var searchText: String
    var onSelectConversation: () -> Void
    var style: SidebarStyle
    
    // 过滤后的对话列表
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return historyService.conversations
        } else {
            return historyService.conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                (conversation.bookTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredConversations) { conversation in
                ConversationItemView(
                    conversation: conversation,
                    isSelected: historyService.currentConversation?.id == conversation.id,
                    style: style,
                    onTap: {
                        viewModel.switchToConversation(conversation)
                        onSelectConversation()
                    }
                )
            }
        }
    }
}

// MARK: - 对话列表项
struct ConversationItemView: View {
    let conversation: Conversation
    var isSelected: Bool = false
    var style: SidebarStyle
    var onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题
            Text(conversation.title)
                .font(.subheadline)
                .foregroundColor(style.textColor)
                .lineLimit(1)
            
            // 时间和书籍信息
            HStack(spacing: 4) {
                if let bookTitle = conversation.bookTitle {
                    Text(bookTitle)
                        .font(.caption2)
                        .foregroundColor(style.secondaryTextColor)
                        .lineLimit(1)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(style.secondaryTextColor)
                }
                
                Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(style.secondaryTextColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Group {
                if isSelected {
                    ZStack {
                        Color.black.opacity(0.1)
                            .background(.ultraThinMaterial)
                        Color.white.opacity(0.03)
                    }
                } else {
                    Color.clear
                }
            }
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - 菜单项
struct MenuItemView: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    var style: SidebarStyle
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? style.titleColor : style.iconColor)
                    .frame(width: 28)
                
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? style.titleColor : style.textColor)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? style.selectedBackgroundColor : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 搜索和新建会话
struct SearchAndNewChatView: View {
    @Binding var searchText: String
    var viewModel: ChatViewModel?
    var onSelectChat: () -> Void
    var style: SidebarStyle
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // 搜索框 - Grok风格
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(style.secondaryTextColor)
                    
                    TextField("Search", text: $searchText)
                        .font(.subheadline)
                        .foregroundColor(style.textColor)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    ZStack {
                        // 液态玻璃效果 - 高透明度
                        Color.white.opacity(0.08)
                        
                        // 微妙的模糊层
                        Color.black.opacity(0.03)
                    }
                    .blur(radius: 10)
                    .background(
                        Color.white.opacity(0.05)
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                
                // 新建会话按钮
                Button(action: {
                    if let viewModel = viewModel {
                        viewModel.startNewConversation()
                        onSelectChat()
                    }
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(style.iconColor)
                        .frame(width: 44, height: 44)
                        .background(
                            ZStack {
                                Color.black.opacity(0.15)
                                    .background(.ultraThinMaterial)
                                Color.white.opacity(0.05)
                            }
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - 用户信息（保留用于其他地方）
struct UserInfoView: View {
    var style: SidebarStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SidebarDivider(style: style)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(style.userAvatarBackground)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(style.iconColor)
                    }
                
                VStack(alignment: .leading) {
                    Text(L("user.name"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(style.titleColor)
                    Text(L("app.description"))
                        .font(.caption)
                        .foregroundColor(style.secondaryTextColor)
                        .lineLimit(1)
                }
            }
            .padding()
        }
    }
}

// MARK: - 分割线
struct SidebarDivider: View {
    var style: SidebarStyle
    
    var body: some View {
        Divider()
            .background(style.dividerColor)
    }
}

// MARK: - 侧边栏样式
struct SidebarStyle {
    var backgroundColor: Color
    var titleColor: Color
    var textColor: Color
    var secondaryTextColor: Color
    var iconColor: Color
    var sectionTitleColor: Color
    var countColor: Color
    var dividerColor: Color
    var selectedBackgroundColor: Color
    var userAvatarBackground: Color
    var searchBackground: Color
    
    // 浅色样式（Mobile）
    static func light(colors: ThemeColors) -> SidebarStyle {
        SidebarStyle(
            backgroundColor: colors.background,
            titleColor: colors.primaryText,
            textColor: colors.primaryText,
            secondaryTextColor: colors.secondaryText,
            iconColor: colors.primaryText,
            sectionTitleColor: colors.secondaryText.opacity(0.7),
            countColor: colors.secondaryText,
            dividerColor: colors.secondaryText.opacity(0.3),
            selectedBackgroundColor: colors.sidebarCardBackground,
            userAvatarBackground: colors.secondaryText.opacity(0.3),
            searchBackground: Color.gray.opacity(0.1)
        )
    }
    
    // 深色样式（Tablet - Journal风格）
    static var dark: SidebarStyle {
        SidebarStyle(
            backgroundColor: Color(red: 0.1, green: 0.1, blue: 0.12),
            titleColor: .white,
            textColor: Color.white.opacity(0.9),
            secondaryTextColor: Color.white.opacity(0.6),
            iconColor: Color.white.opacity(0.7),
            sectionTitleColor: Color.white.opacity(0.5),
            countColor: Color.white.opacity(0.4),
            dividerColor: Color.white.opacity(0.1),
            selectedBackgroundColor: Color.white.opacity(0.15),
            userAvatarBackground: Color.white.opacity(0.1),
            searchBackground: Color.white.opacity(0.08)
        )
    }
}
