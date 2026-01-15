// ChatView.swift - AI 对话视图（支持多语言，类似 ChatGPT 的极简设计）

import SwiftUI

// MARK: - iOS 26 液态玻璃效果按钮样式
struct GlassButtonStyle: ButtonStyle {
    var foregroundColor: Color = .primary
    var shadowColor: Color = .black.opacity(0.15)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(configuration.isPressed ? 0.12 : 0.18),
                                .white.opacity(configuration.isPressed ? 0.02 : 0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: shadowColor, radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 液态玻璃图标按钮样式
struct GlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    var color: Color = .primary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(configuration.isPressed ? 0.15 : 0.25),
                                .white.opacity(configuration.isPressed ? 0.03 : 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.2), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
            .foregroundColor(color)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle {
        GlassButtonStyle()
    }
}

extension ButtonStyle where Self == GlassIconButtonStyle {
    static var glassIcon: GlassIconButtonStyle {
        GlassIconButtonStyle()
    }
}

struct ChatView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var isConversationMode = false
    @State private var showBookPicker = false
    @State private var showSettings = false
    @FocusState private var isInputFocused: Bool
    @StateObject private var sideObser = ExpandSideObservable()
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        ExpandSideView() {
            // 侧边栏（从左侧滑出，非全屏）
            SidebarView(
                colors: colors,
                onSelectChat: {
                    sideObser.jumpToPage(1)
                },
                onSelectBookshelf: {
                    showBookPicker = true
                    sideObser.jumpToPage(1)
                },
                onSelectSettings: {
                    showSettings = true
                    sideObser.jumpToPage(1)
                }
            )
            .environment(appState)
            .environment(themeManager)
            .frame(width: 280)
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
        .onAppear {
            viewModel.appState = appState
        }
    }
    
    // 主聊天内容
    var chatContent: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                
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
                    
                    // 空状态引导（没有选择书籍时显示）
                    if appState.selectedBook == nil && appState.books.isEmpty {
                        EmptyStateView(colors: colors, onAddBook: {
                            showBookPicker = true
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if appState.selectedBook == nil {
                        EmptyChatStateView(colors: colors, onAddBook: {
                            showBookPicker = true
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // 对话列表
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.messages) { message in
                                        MessageBubble(message: message, colors: colors)
                                            .id(message.id)
                                    }
                                }
                                .padding()
                            }
                            .onChange(of: viewModel.messages.count) { _, _ in
                                if let lastMessage = viewModel.messages.last {
                                    withAnimation {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 底部输入栏
                    InputBar(
                        text: $inputText,
                        isConversationMode: $isConversationMode,
                        isFocused: $isInputFocused,
                        isLoading: viewModel.isLoading,
                        speechService: appState.speechService,
                        selectedBook: appState.selectedBook,
                        colors: colors,
                        onSend: sendMessage,
                        onVoice: toggleVoiceInput,
                        onConversation: toggleConversationMode,
                        onSelectBook: { showBookPicker = true },
                        onClearHistory: { viewModel.clearMessages() }
                    )
                }
            }
            .navigationBarHidden(true)
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
            
            // 右侧设置按钮
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(colors.primaryText)
            }
            .buttonStyle(.glassIcon)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(colors.navigationBar)
    }
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let text = inputText
        inputText = ""
        isInputFocused = false
        
        Task {
            await viewModel.sendMessage(text)
            
            if isConversationMode, let lastMessage = viewModel.messages.last, lastMessage.role == .assistant {
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
}

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
                        Text("User")
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
                    .fill(isSelected ? Color.green.opacity(0.6) : Color.white.opacity(0.2))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(isSelected ? 0 : 0.2), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
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
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundColor(colors.secondaryText)
            }
            .buttonStyle(.glassIcon)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(colors.cardBackground)
    }
}

// MARK: - 消息气泡
struct MessageBubble: View {
    let message: ChatMessage
    var colors: ThemeColors = .dark
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                // AI 头像
                Circle()
                    .fill(colors.secondaryText.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "sparkles")
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                    }
            } else {
                Spacer(minLength: 48)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 角色名称
                Text(message.role == .user ? L("common.tips") : "AI")
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
                
                Text(message.content)
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
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(colors.secondaryText.opacity(0.6))
            }
            
            if message.role == .user {
                Spacer(minLength: 48)
            }
        }
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
                .foregroundColor(selectedBook != nil ? .green : colors.secondaryText)
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
                    Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle")
                        .font(.title2)
                        .foregroundColor(speechService.isRecording ? .red : colors.secondaryText)
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
                            .foregroundColor(text.isEmpty ? colors.secondaryText : .green)
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
    
    @MainActor
    func sendMessage(_ text: String) async {
        guard let appState = appState else { return }
        
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        isLoading = true
        
        do {
            let response = try await appState.chatService.sendMessage(
                text,
                bookId: appState.selectedBook?.id,
                history: messages
            )
            
            let assistantMessage = ChatMessage(role: .assistant, content: response)
            messages.append(assistantMessage)
            
        } catch {
            let errorMessage = ChatMessage(role: .assistant, content: L("chat.error.api"))
            messages.append(errorMessage)
        }
        
        isLoading = false
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
                Label(L("chat.emptyState.addBook"), systemImage: "plus.circle.fill")
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
