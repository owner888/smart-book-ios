// MessageBubble.swift - 消息气泡（重构版 - 使用组件化）

import SwiftUI

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
    init(
        message: ChatMessage,
        assistant: Assistant,
        colors: ThemeColors = .dark,
        onSpeak: ((String) -> Void)? = nil,
        onCopy: ((String) -> Void)? = nil,
        onRegenerate: (() -> Void)? = nil
    ) {
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
            // 用户消息：前面用Spacer推到右边
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // 增强模式：显示头像和角色名
                if let assistant = assistant, message.role == .assistant {
                    MessageAssistantHeaderView(assistant: assistant, colors: colors)
                }
                
                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 12) {
                    // 系统提示词（如果有）
                    if let systemPrompt = message.systemPrompt {
                        MessageSystemPromptView(
                            prompt: systemPrompt,
                            colors: colors,
                            isExpanded: $isSystemPromptExpanded
                        )
                    }
                    
                    // 思考过程（如果有）
                    if let thinking = message.thinking, !thinking.isEmpty {
                        MessageThinkingView(
                            thinking: thinking,
                            colors: colors,
                            isExpanded: $isThinkingExpanded
                        )
                    }
                    
                    // 主要内容
                    MessageContentView(message: message, colors: colors)
                    
                    
                    // 停止提示（如果被用户停止）
                    if message.stoppedByUser == true {
                        Text(L("chat.stoppedByUser"))
                            .font(.caption)
                            .foregroundColor(colors.secondaryText.opacity(0.6))
                            .italic()
                            .padding(.top, 4)
                    }
                    // 检索来源（如果有）
                    if let sources = message.sources, !sources.isEmpty {
                        MessageSourcesView(
                            sources: sources,
                            colors: colors,
                            isExpanded: $isSourcesExpanded
                        )
                    }
                    
                    // 使用统计（如果有）
                    if let usage = message.usage {
                        MessageUsageView(usage: usage, colors: colors)
                    }
                    
                    // 消息操作按钮（仅助手消息）
                    if message.role == .assistant {
                        MessageActionsView(
                            colors: colors,
                            onSpeak: onSpeak.map { action in { action(message.content) } },
                            onCopy: onCopy.map { action in { action(message.content) } },
                            onRegenerate: onRegenerate
                        )
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
            
            // 助手消息靠左，右侧留空间
            if message.role == .assistant {
                Spacer(minLength: 48)
            }
        }
    }
}

// MARK: - Preview

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
                    model: "gemini-2.0-flash"
                )
            ),
            assistant: Assistant.defaultAssistants[0],
            colors: .dark
        )
        .padding()
    }
    .background(Color.black)
}
