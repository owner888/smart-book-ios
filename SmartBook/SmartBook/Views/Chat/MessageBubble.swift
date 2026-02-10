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
    @State private var showCopyTip = false  // 复制提示

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
                        // 如果有回调则使用回调，否则使用默认行为
                        if onSpeak != nil || onCopy != nil {
                            MessageActionsView(
                                colors: colors,
                                onSpeak: onSpeak.map { action in { action(message.content) } },
                                onCopy: onCopy.map { action in { action(message.content) } },
                                onRegenerate: onRegenerate
                            )
                        } else {
                            // 简单模式：只显示复制按钮
                            MessageActionsView(
                                colors: colors,
                                onSpeak: nil,  // 简单模式不提供TTS
                                onCopy: {
                                    UIPasteboard.general.string = message.content
                                    // 显示复制提示
                                    showCopyTip = true
                                    // 2秒后自动隐藏
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showCopyTip = false
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(12)
                .background {
                    // 只有用户消息有气泡背景
                    if message.role == .user {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colors.userBubble)
                    }
                }
                .foregroundColor(colors.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)  // 允许垂直扩展，不允许水平扩展
            .contextMenu {
                // 用户消息长按菜单：拷贝
                if message.role == .user {
                    Button(action: {
                        UIPasteboard.general.string = message.content
                    }) {
                        Label(L("chat.contextMenu.copy"), systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .successTips(isShowing: $showCopyTip, message: "Message copied")
    }
}
