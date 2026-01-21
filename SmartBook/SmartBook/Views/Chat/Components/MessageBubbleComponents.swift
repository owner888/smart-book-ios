// MessageBubbleComponents.swift - 消息气泡子组件集合

import SwiftUI
import MarkdownUI

// MARK: - 思考过程视图
struct MessageThinkingView: View {
    let thinking: String
    var colors: ThemeColors
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("Thinking...")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(colors.primaryText)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(thinking)
                    .font(.caption)
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

// MARK: - 消息内容视图
struct MessageContentView: View {
    let message: ChatMessage
    var colors: ThemeColors
    
    var body: some View {
        if message.role == .user {
            Text(message.content)
                .textSelection(.enabled)
        } else {
            Markdown(message.content)
                .markdownTextStyle(\.text) {
                    FontSize(15)
                    ForegroundColor(colors.primaryText)
                }
                .markdownTextStyle(\.code) {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.9))
                    ForegroundColor(.green)
                    BackgroundColor(colors.secondaryText.opacity(0.1))
                }
                .markdownBlockStyle(\.codeBlock) { configuration in
                    configuration.label
                        .padding(12)
                        .background(colors.secondaryText.opacity(0.1))
                        .cornerRadius(8)
                }
                .textSelection(.enabled)
        }
    }
}

// MARK: - 检索来源视图
struct MessageSourcesView: View {
    let sources: [RAGSource]
    var colors: ThemeColors
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "books.vertical")
                        .foregroundColor(.green)
                    Text("📚 检索来源 (\(sources.count))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(colors.primaryText)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sources.prefix(3)) { source in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(source.scorePercentage)%")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.2))
                                )
                            
                            Text(source.text)
                                .font(.caption)
                                .foregroundColor(colors.secondaryText)
                                .lineLimit(3)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.05))
                        )
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.05))
                )
        )
    }
}

// MARK: - 使用统计视图
struct MessageUsageView: View {
    let usage: UsageInfo
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 12) {
            if let model = usage.model {
                Label(model, systemImage: "cpu")
                    .font(.caption2)
            }
            
            if let tokens = usage.tokens {
                if let total = tokens.total {
                    Label(formatTokens(total), systemImage: "chart.bar")
                        .font(.caption2)
                }
                
                if let input = tokens.input {
                    Label("↗\(formatTokens(input))", systemImage: "arrow.up")
                        .font(.caption2)
                }
                
                if let output = tokens.output {
                    Label("↙\(formatTokens(output))", systemImage: "arrow.down")
                        .font(.caption2)
                }
            }
            
            if let cost = usage.cost {
                Label(String(format: "$%.4f", cost), systemImage: "dollarsign.circle")
                    .font(.caption2)
            }
        }
        .foregroundColor(colors.secondaryText)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(colors.secondaryText.opacity(0.1))
        )
    }
    
    private func formatTokens(_ num: Int) -> String {
        if num >= 1000000 {
            return String(format: "%.2fM", Double(num) / 1000000)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000)
        }
        return "\(num)"
    }
}

// MARK: - 消息操作按钮
struct MessageActionsView: View {
    var colors: ThemeColors
    var onSpeak: (() -> Void)?
    var onCopy: (() -> Void)?
    var onRegenerate: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 16) {
            if let speak = onSpeak {
                Button(action: speak) {
                    Label("朗读", systemImage: "speaker.wave.2")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            
            if let copy = onCopy {
                Button(action: copy) {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            
            if let regenerate = onRegenerate {
                Button(action: regenerate) {
                    Label("重新生成", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .foregroundColor(colors.secondaryText)
    }
}

// MARK: - 助手头像视图
struct MessageAssistantHeaderView: View {
    let assistant: Assistant
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(assistant.colorValue.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay {
                    Text(assistant.avatar)
                        .font(.system(size: 12))
                }
            Text(assistant.name)
                .font(.caption)
                .foregroundColor(colors.secondaryText)
        }
    }
}
