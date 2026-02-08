// ChatEmptyStates.swift - 聊天空状态视图

import SwiftUI

// MARK: - 空状态视图（没有书籍时显示）
struct EmptyStateView: View {
    var colors: ThemeColors = .dark
    var onAddBook: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))  // 装饰性大图标
                .foregroundColor(colors.secondaryText.opacity(0.6))

            Text(L("chat.emptyState.title"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(colors.primaryText)

            Text(L("chat.emptyState.desc"))
                .font(.body)
                .foregroundColor(colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onAddBook) {
                Label(
                    L("chat.emptyState.addBook"),
                    systemImage: "plus.circle.fill"
                )
                .font(.headline)
                .foregroundColor(colors.primaryText)
            }
            .buttonStyle(.primaryAction(colors: colors))
            .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - 没有选择书籍时的聊天空状态视图
struct EmptyChatStateView: View {
    var colors: ThemeColors = .dark
    var onAddBook: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))  // 装饰性大图标
                .foregroundColor(colors.secondaryText.opacity(0.6))

            Text(L("chat.emptyState.noBookTitle"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(colors.primaryText)

            Text(L("chat.emptyState.noBookDesc"))
                .font(.body)
                .foregroundColor(colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}
