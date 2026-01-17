// EnhancedChatView.swift - 增强的AI对话视图（完整功能版）

import SwiftUI
import MarkdownUI

struct EnhancedChatView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(AssistantService.self) var assistantService
    @Environment(ModelService.self) var modelService
    
    @State private var chatService = EnhancedChatService()
    @State private var messages: [EnhancedChatMessage] = []
    @State private var inputText = ""
    @State private var showBookPicker = false
    @State private var showSettings = false
    @State private var showBookshelf = false
    @State private var showModelPicker = false
    
    // 流式响应状态
    @State private var streamingContent = ""
    @State private var streamingThinking = ""
    @State private var streamingSources: [RAGSource]? = nil
    @State private var streamingUsage: UsageInfo? = nil
    @State private var streamingSystemPrompt: String? = nil
    @State private var isStreaming = false
    
    @FocusState private var isInputFocused: Bool
    @StateObject private var sideObser = ExpandSideObservable()
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    private var currentAssistant: Assistant {
        assistantService.currentAssistant
    }
    
    var body: some View {
        ExpandSideView {
            // 侧边栏
            EnhancedSidebarView(
                colors: colors,
                onSelectChat: {
                    sideObser.jumpToPage(1)
                },
                onSelectBookshelf: {
                    showBookshelf = true
                    sideObser.jumpToPage(1)
                },
                onSelectSettings: {
                    showSettings = true
                    sideObser.jumpToPage(1)
                },
                onSwitchAssistant: { assistant in
                    // 切换助手时清空消息
                    messages.removeAll()
                }
            )
            .environment(assistantService)
            .frame(width: 280)
            .background(colors.cardBackground)
        } content: {
            chatContent
        }
        .environmentObject(sideObser)
        .sheet(isPresented: $showBookPicker) {
            BookPickerView(colors: colors) { book in
                withAnimation {
                    appState.selectedBook = book
                }
                showBookPicker = false
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(appState)
                .environment(themeManager)
        }
        .sheet(isPresented: $showBookshelf) {
            BookshelfView()
                .environment(appState)
                .environment(themeManager)
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerView(colors: colors)
                .environment(modelService)
        }
        .task {
            // 加载助手和模型
            try? await assistantService.loadAssistants()
            try? await modelService.loadModels()
        }
    }
    
    // 主聊天内容
    var chatContent: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    colors.background.ignoresSafeArea()
                    
                    InputToolBarView(inputText: $inputText, content: {
                        VStack(spacing: 0) {
                            // 顶部栏
                            topBar
                            
                            // 书籍上下文栏
                            if let book = appState.selectedBook {
                                BookContextBar(book: book, colors: colors) {
                                    withAnimation {
                                        appState.selectedBook = nil
                                    }
                                }
                            }
                            
                            // 消息列表
                            messagesView
                        }
                    }, onSend: sendMessage)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // 顶部栏
    var topBar: some View {
        HStack(spacing: 12) {
            // 菜单按钮
            Button(action: { sideObser.jumpToPage(0) }) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(colors.primaryText)
            }
            .glassEffect()
            
            // 助手信息
            HStack(spacing: 8) {
                Circle()
                    .fill(currentAssistant.colorValue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(currentAssistant.avatar)
                            .font(.system(size: 16))
                    }
                
                Text(currentAssistant.name)
                    .font(.headline)
                    .foregroundColor(colors.primaryText)
            }
            
            Spacer()
            
            // 模型选择器
            Button(action: { showModelPicker = true }) {
                HStack(spacing: 4) {
                    Text("🤖")
                    Text(modelService.currentModel.name)
                        .font(.caption)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(colors.primaryText)
            }
            .glassEffect()
            
            // 设置按钮
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(colors.primaryText)
            }
            .glassEffect()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(colors.navigationBar)
    }
    
    // 消息列表视图
    @ViewBuilder
    var messagesView: some View {
        if messages.isEmpty && !isStreaming {
            // 空状态
            if appState.selectedBook == nil && appState.books.isEmpty {
                EmptyStateView(
                    colors: colors,
                    onAddBook: { showBookPicker = true }
                )
            } else if appState.selectedBook == nil {
                EmptyChatStateView(
                    colors: colors,
                    onAddBook: { showBookPicker = true }
                )
            } else {
                // 欢迎消息
                welcomeView
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            EnhancedMessageBubble(
                                message: message,
                                assistant: currentAssistant,
                                colors: colors,
                                onSpeak: { content in
                                    Task {
                                        await appState.ttsService.speak(content)
                                    }
                                },
                                onCopy: { content in
                                    UIPasteboard.general.string = content
                                },
                                onRegenerate: {
                                    regenerateLastMessage()
                                }
                            )
                            .id(message.id)
                        }
                        
                        // 流式消息
                        if isStreaming {
                            StreamingMessageBubble(
                                assistant: currentAssistant,
                                content: streamingContent,
                                thinking: streamingThinking.isEmpty ? nil : streamingThinking,
                                colors: colors
                            )
                            .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: isStreaming) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: streamingContent) { _, _ in
                    scrollToBottom(proxy)
                }
            }
        }
    }
    
    // 欢迎视图
    var welcomeView: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(currentAssistant.colorValue.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay {
                    Text(currentAssistant.avatar)
                        .font(.system(size: 40))
                }
            
            Text(currentAssistant.name)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(colors.primaryText)
            
            Text(currentAssistant.description)
                .font(.body)
                .foregroundColor(colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // 快捷操作建议
            if currentAssistant.action == .ask {
                quickSuggestionsView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // 快捷建议
    var quickSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("试试这些问题：")
                .font(.caption)
                .foregroundColor(colors.secondaryText)
            
            ForEach(["总结这本书的主要内容", "这本书的主题是什么？", "作者想表达什么观点？"], id: \.self) { suggestion in
                Button(action: {
                    inputText = suggestion
                    sendMessage()
                }) {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(colors.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colors.secondaryText.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
    }
    
    // 发送消息
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isStreaming else { return }
        
        let text = inputText
        inputText = ""
        isInputFocused = false
        
        // 添加用户消息
        let userMessage = EnhancedChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        // 重置流式状态
        streamingContent = ""
        streamingThinking = ""
        streamingSources = nil
        streamingUsage = nil
        streamingSystemPrompt = nil
        isStreaming = true
        
        // 发送流式请求
        chatService.sendMessageStream(
            message: text,
            assistant: currentAssistant,
            bookId: appState.selectedBook?.id,
            model: modelService.currentModel.id,
            ragEnabled: currentAssistant.useRAG
        ) { event in
            handleSSEEvent(event)
        } onComplete: { result in
            isStreaming = false
            
            switch result {
            case .success:
                // 完成流式响应，添加完整消息
                let assistantMessage = EnhancedChatMessage(
                    role: .assistant,
                    content: streamingContent,
                    thinking: streamingThinking.isEmpty ? nil : streamingThinking,
                    sources: streamingSources,
                    usage: streamingUsage,
                    systemPrompt: streamingSystemPrompt
                )
                messages.append(assistantMessage)
                
            case .failure(let error):
                // 错误处理
                let errorMessage = EnhancedChatMessage(
                    role: .assistant,
                    content: "❌ 请求失败: \(error.localizedDescription)"
                )
                messages.append(errorMessage)
            }
        }
    }
    
    // 处理SSE事件
    func handleSSEEvent(_ event: SSEEvent) {
        switch event {
        case .systemPrompt(let prompt):
            streamingSystemPrompt = prompt
            
        case .thinking(let thinking):
            streamingThinking += thinking
            
        case .content(let content):
            streamingContent += content
            
        case .sources(let sources):
            streamingSources = sources
            
        case .usage(let usage):
            streamingUsage = usage
            
        case .cached(let hit):
            if hit {
                // 显示缓存命中提示
                print("📦 Cache hit!")
            }
            
        case .error(let error):
            streamingContent = "❌ 错误: \(error)"
            
        case .done:
            break
        }
    }
    
    // 重新生成最后一条消息
    func regenerateLastMessage() {
        guard messages.count >= 2 else { return }
        
        // 移除最后一条助手消息
        messages.removeLast()
        
        // 获取最后一条用户消息
        if let lastUserMessage = messages.last, lastUserMessage.role == .user {
            messages.removeLast()
            inputText = lastUserMessage.content
            sendMessage()
        }
    }
    
    // 滚动到底部
    func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                if isStreaming {
                    proxy.scrollTo("streaming", anchor: .bottom)
                } else if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - 模型选择器
struct ModelPickerView: View {
    @Environment(ModelService.self) var modelService
    @Environment(\.dismiss) var dismiss
    var colors: ThemeColors
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(modelService.models) { model in
                    Button(action: {
                        modelService.switchModel(model)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.name)
                                    .font(.headline)
                                
                                Text(model.provider)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if model.id == modelService.currentModel.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EnhancedChatView()
        .environment(AppState())
        .environment(ThemeManager.shared)
        .environment(AssistantService())
        .environment(ModelService())
}
