// StreamingMessageBubble.swift - 流式消息气泡（显示打字效果）

import SwiftUI
import MarkdownUI

struct StreamingMessageBubble: View {
    let assistant: Assistant
    let content: String
    let thinking: String?
    var colors: ThemeColors = .dark
    
    @State private var isThinkingExpanded = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI 头像
            Circle()
                .fill(assistant.colorValue.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(assistant.avatar)
                        .font(.body) // 17号 - 动态字号
                }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(assistant.name)
                    .font(.caption) // 12号 - 动态字号
                    .foregroundColor(colors.secondaryText)
                
                VStack(alignment: .leading, spacing: 12) {
                    // 思考过程（如果有）
                    if let thinking = thinking, !thinking.isEmpty {
                        thinkingView(thinking)
                    }
                    
                    // 内容（可能为空，显示打字指示器）
                    if content.isEmpty {
                        TypingIndicator(colors: colors)
                    } else {
                        Markdown(content)
                            .markdownTextStyle(\.text) {
                                FontSize(15)
                                ForegroundColor(colors.primaryText)
                            }
                    }
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colors.assistantBubble)
                }
                .foregroundColor(colors.primaryText)
            }
            
            Spacer(minLength: 48)
        }
    }
    
    // MARK: - 思考过程视图
    
    @ViewBuilder
    private func thinkingView(_ thinking: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isThinkingExpanded.toggle() }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("Thinking...")
                        .font(.caption) // 12号 - 动态字号
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isThinkingExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption) // 12号 - 动态字号
                }
                .foregroundColor(colors.primaryText)
            }
            .buttonStyle(.plain)
            
            if isThinkingExpanded {
                Text(thinking)
                    .font(.caption) // 12号 - 动态字号
                    .foregroundColor(colors.secondaryText)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.1))
                    )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.05))
                )
        )
    }
}
