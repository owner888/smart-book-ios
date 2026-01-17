// EnhancedSidebarView.swift - 增强的侧边栏视图（支持助手切换）

import SwiftUI

// MARK: - 增强的侧边栏视图
struct EnhancedSidebarView: View {
    @Environment(AssistantService.self) var assistantService
    var colors: ThemeColors
    var onSelectChat: () -> Void
    var onSelectBookshelf: () -> Void
    var onSelectSettings: () -> Void
    var onSwitchAssistant: ((Assistant) -> Void)?
    
    @State private var selectedTab: SidebarTab = .assistants
    
    enum SidebarTab: String {
        case assistants = "Assistants"
        case topics = "Topics"
    }
    
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
                    .foregroundColor(colors.primaryText)
            }
            .padding()
            
            Divider()
                .background(colors.secondaryText.opacity(0.3))
            
            // 标签切换
            HStack(spacing: 0) {
                ForEach([SidebarTab.assistants, SidebarTab.topics], id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundColor(selectedTab == tab ? colors.primaryText : colors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selectedTab == tab ?
                                    colors.secondaryText.opacity(0.1) : Color.clear
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            Divider()
                .background(colors.secondaryText.opacity(0.3))
            
            // 内容区域
            ScrollView {
                if selectedTab == .assistants {
                    assistantsContent
                } else {
                    topicsContent
                }
            }
            
            Spacer()
            
            // 底部导航
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                    .background(colors.secondaryText.opacity(0.3))
                
                // 书架
                SidebarItem(
                    icon: "books.vertical",
                    title: L("library.title"),
                    colors: colors,
                    isSelected: false,
                    action: onSelectBookshelf
                )
                
                // 设置
                SidebarItem(
                    icon: "gearshape",
                    title: L("settings.title"),
                    colors: colors,
                    isSelected: false,
                    action: onSelectSettings
                )
                
                Divider()
                    .background(colors.secondaryText.opacity(0.3))
                
                // 用户信息
                HStack(spacing: 12) {
                    Circle()
                        .fill(colors.secondaryText.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundColor(colors.primaryText)
                        }
                    
                    VStack(alignment: .leading) {
                        Text("User")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(colors.primaryText)
                        Text(L("app.description"))
                            .font(.caption)
                            .foregroundColor(colors.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding()
            }
        }
        .background(colors.cardBackground)
    }
    
    // 助手列表内容
    @ViewBuilder
    private var assistantsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 添加助手按钮
            Button(action: {
                // TODO: 实现添加自定义助手
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text("Add Assistant")
                        .fontWeight(.medium)
                }
                .foregroundColor(colors.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colors.secondaryText.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // 助手列表
            ForEach(assistantService.assistants) { assistant in
                AssistantItem(
                    assistant: assistant,
                    isSelected: assistant.id == assistantService.currentAssistant.id,
                    colors: colors,
                    onSelect: {
                        assistantService.switchAssistant(assistant)
                        onSwitchAssistant?(assistant)
                        onSelectChat()
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    // 主题列表内容
    @ViewBuilder
    private var topicsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("对话历史")
                .font(.caption)
                .foregroundColor(colors.secondaryText)
                .padding(.horizontal)
                .padding(.top, 8)
            
            // TODO: 实现对话历史列表
            Text("暂无对话历史")
                .font(.subheadline)
                .foregroundColor(colors.secondaryText.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
    }
}

// MARK: - 助手项
struct AssistantItem: View {
    let assistant: Assistant
    let isSelected: Bool
    var colors: ThemeColors
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 头像
                Circle()
                    .fill(assistant.colorValue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(assistant.avatar)
                            .font(.system(size: 20))
                    }
                
                // 名称和描述
                VStack(alignment: .leading, spacing: 2) {
                    Text(assistant.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(colors.primaryText)
                    
                    Text(assistant.description)
                        .font(.caption)
                        .foregroundColor(colors.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 更多菜单
                Button(action: {
                    // TODO: 显示助手菜单
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(colors.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ?
                            assistant.colorValue.opacity(0.15) :
                            Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? assistant.colorValue.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

#Preview {
    EnhancedSidebarView(
        colors: .dark,
        onSelectChat: {},
        onSelectBookshelf: {},
        onSelectSettings: {}
    )
    .environment(AssistantService())
    .frame(width: 280)
}
