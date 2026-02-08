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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App 标题
            AppTitleView(style: style)
            
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
                        style: style
                    )
                    
                    SidebarDivider(style: style)
                        .padding(.vertical, 8)
                }
            }
            
            // 底部固定区域
            BottomMenuView(
                onSelectBookshelf: onSelectBookshelf,
                onSelectSettings: onSelectSettings,
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
                        onSelectConversation: onSelectChat,
                        style: style
                    )
                    .padding(.horizontal, 12)
                }
            }
        }
    }
}

// MARK: - 对话列表
struct ConversationsListView: View {
    var historyService: ChatHistoryService
    var viewModel: ChatViewModel
    var onSelectConversation: () -> Void
    var style: SidebarStyle
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(historyService.conversations) { conversation in
                Button(action: {
                    viewModel.switchToConversation(conversation)
                    onSelectConversation()
                }) {
                    ConversationItemView(
                        conversation: conversation,
                        isSelected: historyService.currentConversation?.id == conversation.id,
                        style: style
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 对话列表项
struct ConversationItemView: View {
    let conversation: Conversation
    var isSelected: Bool = false
    var style: SidebarStyle
    
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
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? style.selectedBackgroundColor : Color.clear)
        )
    }
}

// MARK: - 底部菜单
struct BottomMenuView: View {
    var onSelectBookshelf: () -> Void
    var onSelectSettings: () -> Void
    var style: SidebarStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarDivider(style: style)
            
            // 菜单项
            VStack(alignment: .leading, spacing: 4) {
                MenuItemView(
                    icon: "book",
                    title: L("library.title"),
                    isSelected: false,
                    style: style,
                    action: onSelectBookshelf
                )
                
                MenuItemView(
                    icon: "gearshape",
                    title: L("settings.title"),
                    isSelected: false,
                    style: style,
                    action: onSelectSettings
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // 用户信息
            UserInfoView(style: style)
        }
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

// MARK: - 用户信息
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
            userAvatarBackground: colors.secondaryText.opacity(0.3)
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
            selectedBackgroundColor: Color(white: 0.11),
            userAvatarBackground: Color.white.opacity(0.1)
        )
    }
}
