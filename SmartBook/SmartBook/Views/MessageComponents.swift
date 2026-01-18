// MessageComponents.swift - 消息组件

import SwiftUI
import MarkdownUI

// MARK: - 消息气泡（智能适配简单和增强模式）
struct MessageBubble: View {
    let message: ChatMessage
    let assistant: Assistant?  // 可选，简单模式时为nil
    var colors: ThemeColors = .dark
    var onSpeak: ((String) -> Void)?
    var onCopy: ((String) -> Void)?
    var onRegenerate: (() -> Void)?
    
    // 简单模式初始化器
    init(message: ChatMessage, colors: ThemeColors = .dark) {
        self.message = message
        self.assistant = nil
        self.colors = colors
        self.onSpeak = nil
        self.onCopy = nil
        self.onRegenerate = nil
    }
    
    // 增强模式初始化器
    init(message: ChatMessage, assistant: Assistant, colors: ThemeColors = .dark, onSpeak: ((String) -> Void)? = nil, onCopy: ((String) -> Void)? = nil, onRegenerate: (() -> Void)? = nil) {
        self.message = message
        self.assistant = assistant
        self.colors = colors
        self.onSpeak = onSpeak
        self.onCopy = onCopy
        self.onRegenerate = onRegenerate
    }
    
    @State private var isThinkingExpanded = false
    @State private var isSystemPromptExpanded = false
    @State private var isSourcesExpanded = true
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // 增强模式：显示头像和角色名
                if let assistant = assistant, message.role == .assistant {
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
                
                VStack(alignment: .leading, spacing: 12) {
                    // 系统提示词（如果有）
                    if let systemPrompt = message.systemPrompt {
                        systemPromptView(systemPrompt)
                    }
                    
                    // 思考过程（如果有）
                    if let thinking = message.thinking, !thinking.isEmpty {
                        thinkingView(thinking)
                    }
                    
                    // 主要内容
                    messageContentView
                    
                    // 检索来源（如果有）
                    if let sources = message.sources, !sources.isEmpty {
                        sourcesView(sources)
                    }
                    
                    // 使用统计（如果有）
                    if let usage = message.usage {
                        usageView(usage)
                    }
                    
                    // 消息操作按钮（仅助手消息）
                    if message.role == .assistant {
                        messageActionsView
                    }
                }
                .padding(12)
                .background {
                    if message.role == .user {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colors.userBubble)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colors.assistantBubble)
                    }
                }
                .foregroundColor(colors.primaryText)
                
                // 时间戳
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(colors.secondaryText.opacity(0.6))
            }
            
            if message.role == .user {
                Spacer(minLength: 48)
            }
        }
    }
    
    // 系统提示词视图
    @ViewBuilder
    private func systemPromptView(_ prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isSystemPromptExpanded.toggle() }) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text("系统提示词")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isSystemPromptExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(colors.primaryText)
            }
            .buttonStyle(.plain)
            
            if isSystemPromptExpanded {
                Text(prompt)
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.05))
                )
        )
    }
    
    // 思考过程视图
    @ViewBuilder
    private func thinkingView(_ thinking: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isThinkingExpanded.toggle() }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("Thinking...")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isThinkingExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(colors.primaryText)
            }
            .buttonStyle(.plain)
            
            if isThinkingExpanded {
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
    
    // 消息内容视图
    @ViewBuilder
    private var messageContentView: some View {
        if message.role == .user {
            Text(message.content)
                .textSelection(.enabled)
        } else {
            // 使用 Markdown 渲染
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
    
    // 检索来源视图
    @ViewBuilder
    private func sourcesView(_ sources: [RAGSource]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isSourcesExpanded.toggle() }) {
                HStack {
                    Image(systemName: "books.vertical")
                        .foregroundColor(.green)
                    Text("📚 检索来源 (\(sources.count))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isSourcesExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(colors.primaryText)
            }
            .buttonStyle(.plain)
            
            if isSourcesExpanded {
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
    
    // 使用统计视图
    @ViewBuilder
    private func usageView(_ usage: UsageInfo) -> some View {
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
    
    // 消息操作按钮
    @ViewBuilder
    private var messageActionsView: some View {
        HStack(spacing: 16) {
            // 朗读按钮
            Button(action: {
                onSpeak?(message.content)
            }) {
                Label("朗读", systemImage: "speaker.wave.2")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            
            // 复制按钮
            Button(action: {
                onCopy?(message.content)
            }) {
                Label("复制", systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            
            // 重新生成按钮
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
    
    // 格式化 token 数量
    private func formatTokens(_ num: Int) -> String {
        if num >= 1000000 {
            return String(format: "%.2fM", Double(num) / 1000000)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000)
        }
        return "\(num)"
    }
}

// MARK: - 流式消息气泡（显示打字效果）
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
                        .font(.system(size: 18))
                }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(assistant.name)
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
                
                VStack(alignment: .leading, spacing: 12) {
                    // 思考过程（如果有）
                    if let thinking = thinking, !thinking.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: { isThinkingExpanded.toggle() }) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.purple)
                                    Text("Thinking...")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: isThinkingExpanded ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(colors.primaryText)
                            }
                            .buttonStyle(.plain)
                            
                            if isThinkingExpanded {
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
}

// MARK: - 打字指示器
struct TypingIndicator: View {
    var colors: ThemeColors = .dark
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(colors.secondaryText.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    VStack {
        // 简单模式示例
        MessageBubble(
            message: ChatMessage(role: .user, content: "你好"),
            colors: .dark
        )
        
        // 增强模式示例
        MessageBubble(
            message: ChatMessage(
                role: .assistant,
                content: "这是一条测试消息",
                thinking: "我正在思考如何回答...",
                sources: [
                    RAGSource(text: "这是第一个检索来源", score: 0.95),
                    RAGSource(text: "这是第二个检索来源", score: 0.88)
                ],
                usage: UsageInfo(
                    tokens: TokenInfo(input: 1000, output: 500, total: 1500),
                    cost: 0.0023,
                    model: "gemini-2.0-flash-exp"
                )
            ),
            assistant: Assistant.defaultAssistants[0],
            colors: .dark
        )
        .padding()
    }
    .background(Color.black)
}
