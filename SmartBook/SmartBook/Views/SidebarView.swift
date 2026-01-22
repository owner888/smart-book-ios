// SidebarView.swift - 侧边栏视图

import SwiftUI

// MARK: - 侧边栏视图
struct SidebarView: View {
    var colors: ThemeColors
    var onSelectChat: () -> Void
    var onSelectBookshelf: () -> Void
    var onSelectSettings: () -> Void

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

            // 菜单项
            VStack(alignment: .leading, spacing: 4) {
                // 当前对话
                SidebarItem(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: L("chat.title"),
                    colors: colors,
                    isSelected: true,
                    action: onSelectChat
                )

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
            }
            .padding(.horizontal, 12)
            .padding(.vertical)

            Spacer()

            // 底部用户信息
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .background(colors.secondaryText.opacity(0.3))

                HStack(spacing: 12) {
                    Circle()
                        .fill(colors.secondaryText.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundColor(colors.primaryText)
                        }

                    VStack(alignment: .leading) {
                        Text(L("user.name"))
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
}

// MARK: - 侧边栏菜单项
struct SidebarItem: View {
    let icon: String
    let title: String
    var colors: ThemeColors
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : colors.primaryText)
                    .frame(width: 28)

                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : colors.primaryText)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ? Color.apprBlack.opacity(0.1) : Color.white.opacity(0.001)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
