// ChatInputComponents.swift - 聊天输入组件（仅保留使用中的组件）

import SwiftUI

// MARK: - 书籍状态栏
struct BookContextBar: View {
    let book: Book
    var colors: ThemeColors = .dark
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.fill")
                .foregroundColor(.green)

            Text(String(format: L("chat.readingBook"), book.title))
                .font(.caption)
                .foregroundColor(colors.primaryText.opacity(0.8))
                .lineLimit(1)

            Spacer()

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(colors.secondaryText)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(colors.secondaryText.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(colors.cardBackground)
    }
}

// MARK: - 助手系统提示词栏
struct AssistantPromptBar: View {
    let assistant: Assistant
    var colors: ThemeColors = .dark
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏（可点击展开/折叠）
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Text(assistant.avatar)
                        .font(.title3)

                    Text(assistant.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(colors.primaryText.opacity(0.9))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(colors.secondaryText)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 系统提示词内容（可展开）
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .background(colors.secondaryText.opacity(0.2))

                    Text(assistant.systemPrompt)
                        .font(.caption2)
                        .foregroundColor(colors.secondaryText)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }
        }
        .background(assistant.colorValue.opacity(0.1))
    }
}
