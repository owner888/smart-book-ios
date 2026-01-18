// ChatView.swift - AI 对话视图（支持多语言，类似 ChatGPT 的极简设计）

import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var isConversationMode = false
    @State private var showBookPicker = false
    @State private var showSettings = false
    @State private var showBookshelf = false
    
    @FocusState private var isInputFocused: Bool
    @StateObject private var sideObser = ExpandSideObservable()
 

    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }

    var body: some View {
        ExpandSideView {
            // 侧边栏（从左侧滑出，非全屏）
            SidebarView(
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
                }
            )
            .environment(appState)
            .environment(themeManager)
            .frame(width: 340)
            .background(colors.cardBackground)
        } content: {
            chatContent
        }.environmentObject(sideObser).sheet(isPresented: $showBookPicker) {
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
        }.onAppear {
            viewModel.appState = appState
        }
    }

    // 主聊天内容
    var chatContent: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack() {
                    colors.background.ignoresSafeArea()
                    InputToolBarView(inputText: $inputText, content: { keyboardHeight in
                        // 聊天内容区域
                        VStack(spacing: 0) {
                            // 顶部栏
                            topBar

                            if let book = appState.selectedBook {
                                BookContextBar(book: book, colors: colors) {
                                    withAnimation {
                                        appState.selectedBook = nil
                                    }
                                }
                            }

                            // 对话列表（始终显示，无论是否选择书籍）
                            if viewModel.messages.isEmpty {
                                // 空状态提示
                                if appState.books.isEmpty {
                                    EmptyStateView(
                                        colors: colors,
                                        onAddBook: {
                                            showBookPicker = true
                                        }
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: .infinity
                                    )
                                } else {
                                    EmptyChatStateView(
                                        colors: colors,
                                        onAddBook: {
                                            showBookPicker = true
                                        }
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: .infinity
                                    )
                                }
                            } else {
                                // 有消息时显示对话列表
                                ScrollViewReader { proxy in
                                    ScrollView {
                                        LazyVStack(spacing: 12) {
                                            ForEach(viewModel.messages) {
                                                message in
                                                MessageBubble(
                                                    message: message,
                                                    colors: colors
                                                )
                                                .id(message.id)
                                            }
                                        }
                                        .padding()
                                        .padding(.bottom, 100 + keyboardHeight) // 给输入栏和键盘留出空间
                                    }
                                    .onChange(of: viewModel.messages.count) {
                                        _,
                                        _ in
                                        if let lastMessage = viewModel.messages
                                            .last
                                        {
                                            // 延迟一点让UI更新完成
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                withAnimation {
                                                    proxy.scrollTo(
                                                        lastMessage.id,
                                                        anchor: .bottom
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }, onSend: sendMessage)

                    // InputBar - 根据键盘高度调整位置
                    //                InputBar(
                    //                    text: $inputText,
                    //                    isConversationMode: $isConversationMode,
                    //                    isFocused: $isInputFocused,
                    //                    isLoading: viewModel.isLoading,
                    //                    speechService: appState.speechService,
                    //                    selectedBook: appState.selectedBook,
                    //                    colors: colors,
                    //                    onSend: sendMessage,
                    //                    onVoice: toggleVoiceInput,
                    //                    onConversation: toggleConversationMode,
                    //                    onSelectBook: { showBookPicker = true },
                    //                    onClearHistory: { viewModel.clearMessages() }
                    //                )
                    //                .offset(y: -keyboardHeight)
                    //                .ignoresSafeArea(.keyboard)
        
                }
                
            }.navigationBarHidden(true)
        }
    }
    
    

    // 顶部栏
    var topBar: some View {
        HStack(spacing: 12) {
            // 左侧菜单按钮
            Button(action: { sideObser.jumpToPage(0) }) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(colors.primaryText)
            }.glassEffect()

            Spacer()

            // 标题
            Text(L("chat.title"))
                .font(.headline)
                .foregroundColor(colors.primaryText)

            Spacer()

            // 右侧更多菜单按钮
            Menu {
                Button(action: { showBookPicker = true }) {
                    Label(L("chat.menu.selectBook"), systemImage: "book")
                }
                
                Divider()
                
                Button(action: { viewModel.clearMessages() }) {
                    Label(L("chat.menu.clearHistory"), systemImage: "trash")
                }
                .disabled(viewModel.messages.isEmpty)
                
                Button(action: { exportConversation() }) {
                    Label(L("chat.menu.exportChat"), systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.messages.isEmpty)
                
                Divider()
                
                Button(action: { showSettings = true }) {
                    Label(L("chat.menu.settings"), systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(colors.primaryText)
            }
            .menuGlassEffect()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(colors.navigationBar)
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        let text = inputText
        inputText = ""
        
        // 立即收起键盘
        hiddenKeyboard()
        isInputFocused = false

        Task {
            await viewModel.sendMessage(text)

            if isConversationMode, let lastMessage = viewModel.messages.last,
                lastMessage.role == .assistant
            {
                await appState.ttsService.speak(lastMessage.content)
                startVoiceInput()
            }
        }
    }

    func toggleVoiceInput() {
        if appState.speechService.isRecording {
            appState.speechService.stopRecording()
        } else {
            startVoiceInput()
        }
    }

    func startVoiceInput() {
        appState.speechService.startRecording { result in
            inputText = result
        } onFinal: { finalResult in
            inputText = finalResult
            if isConversationMode {
                sendMessage()
            }
        }
    }

    func toggleConversationMode() {
        isConversationMode.toggle()
        if isConversationMode {
            startVoiceInput()
        } else {
            appState.speechService.stopRecording()
            appState.ttsService.stop()
        }
    }
    
    func exportConversation() {
        // 生成对话文本
        var exportText = "# Chat Export\n\n"
        
        for message in viewModel.messages {
            let role = message.role == .user ? "User" : "AI"
            let timestamp = message.timestamp.formatted(date: .abbreviated, time: .shortened)
            exportText += "**\(role)** (\(timestamp)):\n\(message.content)\n\n---\n\n"
        }
        
        // 使用系统分享
        let activityVC = UIActivityViewController(
            activityItems: [exportText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }


}

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

// MARK: - 输入栏
struct InputBar: View {
    @Binding var text: String
    @Binding var isConversationMode: Bool
    var isFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let speechService: SpeechService
    var selectedBook: Book?
    var colors: ThemeColors = .dark
    let onSend: () -> Void
    let onVoice: () -> Void
    let onConversation: () -> Void
    let onSelectBook: () -> Void
    let onClearHistory: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：书籍选择器
            Button(action: onSelectBook) {
                HStack(spacing: 4) {
                    if let book = selectedBook {
                        Image(systemName: "book.fill")
                            .font(.title3)
                    } else {
                        Image(systemName: "books.vertical")
                            .font(.title3)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(
                    selectedBook != nil ? .green : colors.secondaryText
                )
            }
            .buttonStyle(.glassIcon)

            // 中间：输入框
            TextField(L("chat.placeholder"), text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colors.inputBackground)
                }
                .foregroundColor(colors.primaryText)
                .focused(isFocused)
                .lineLimit(1...5)

            // 右侧：功能按钮
            HStack(spacing: 8) {
                // 语音输入
                Button(action: onVoice) {
                    Image(
                        systemName: speechService.isRecording
                            ? "stop.circle.fill" : "mic.circle"
                    )
                    .font(.title2)
                    .foregroundColor(
                        speechService.isRecording ? .red : colors.secondaryText
                    )
                    .symbolEffect(.bounce, value: speechService.isRecording)
                }
                .buttonStyle(.glassIcon)

                // 发送按钮
                Button(action: onSend) {
                    if isLoading {
                        ProgressView()
                            .tint(colors.primaryText)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(
                                text.isEmpty ? colors.secondaryText : .green
                            )
                    }
                }
                .buttonStyle(.glassIcon)
                .disabled(isLoading || text.isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(colors.cardBackground)
    }
}

// MARK: - ChatViewModel
@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var isLoading = false
    
    var appState: AppState?
    private let streamingService = StreamingChatService()
    private var streamingContent = ""

    @MainActor
    func sendMessage(_ text: String) async {
        guard let appState = appState else { return }

        Logger.info("📤 发送消息: \(text)")

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isLoading = true
        streamingContent = ""
        
        // 创建一个临时的助手消息用于流式更新
        let streamingMessage = ChatMessage(role: .assistant, content: "")
        messages.append(streamingMessage)
        let messageIndex = messages.count - 1
        
        // 使用流式API
        streamingService.sendMessageStream(
            message: text,
            assistant: Assistant.defaultAssistants.first!,
            bookId: appState.selectedBook?.id,
            model: "gemini-2.0-flash-exp",
            ragEnabled: true
        ) { [weak self] event in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch event {
                case .content(let content):
                    Logger.info("💬 收到内容: \(content)")
                    // 逐步更新内容
                    self.streamingContent += content
                    if messageIndex < self.messages.count {
                        self.messages[messageIndex] = ChatMessage(
                            role: .assistant,
                            content: self.streamingContent
                        )
                    }
                    
                case .error(let error):
                    if messageIndex < self.messages.count {
                        self.messages[messageIndex] = ChatMessage(
                            role: .assistant,
                            content: "❌ 错误: \(error)"
                        )
                    }
                    
                default:
                    break
                }
            }
        } onComplete: { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .failure(let error):
                    if messageIndex < self.messages.count {
                        self.messages[messageIndex] = ChatMessage(
                            role: .assistant,
                            content: "❌ 请求失败: \(error.localizedDescription)"
                        )
                    }
                case .success:
                    // 流式完成，内容已经在事件中更新
                    break
                }
            }
        }
    }

    func clearMessages() {
        messages.removeAll()
    }
}

// MARK: - 空状态视图（没有书籍时显示）
struct EmptyStateView: View {
    var colors: ThemeColors = .dark
    var onAddBook: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
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
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.glass)
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
                .font(.system(size: 64))
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

#Preview {
    ChatView()
        .environment(AppState())
        .environment(ThemeManager.shared)
}

extension CGRect {
    func edgeInset(_ size: CGSize) -> EdgeInsets {
        EdgeInsets(
            top: minY,
            leading: minX,
            bottom: size.height - maxY,
            trailing: size.width - maxX
        )
    }
}
