// ChatView.swift - AI 对话视图（支持主题切换）

import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var isConversationMode = false
    @FocusState private var isInputFocused: Bool
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 当前书籍提示
                    if let book = appState.selectedBook {
                        BookContextBar(book: book, colors: colors)
                    }
                    
                    // 消息列表
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
                    
                    // 输入区域
                    InputBar(
                        text: $inputText,
                        isConversationMode: $isConversationMode,
                        isFocused: $isInputFocused,
                        isLoading: viewModel.isLoading,
                        speechService: appState.speechService,
                        colors: colors,
                        onSend: sendMessage,
                        onVoice: toggleVoiceInput,
                        onConversation: toggleConversationMode
                    )
                }
            }
            .navigationTitle("AI 对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.navigationBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isInputFocused = false
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("清空对话", systemImage: "trash") {
                            viewModel.clearMessages()
                        }
                        Button("选择书籍", systemImage: "book") {
                            // TODO: 选择书籍
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(colors.primaryText)
                    }
                }
            }
        }
        .onAppear {
            viewModel.appState = appState
        }
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

// MARK: - 书籍上下文栏
struct BookContextBar: View {
    let book: Book
    var colors: ThemeColors = .dark
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.fill")
                .foregroundColor(.green)
            
            Text("正在阅读: \(book.title)")
                .font(.caption)
                .foregroundColor(colors.primaryText.opacity(0.8))
            
            Spacer()
            
            Button {
                // 清除选择
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(colors.secondaryText)
            }
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
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
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
                    .foregroundColor(colors.secondaryText)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
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
    var colors: ThemeColors = .dark
    let onSend: () -> Void
    let onVoice: () -> Void
    let onConversation: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 对话模式按钮
            Button(action: onConversation) {
                Image(systemName: isConversationMode ? "waveform.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundColor(isConversationMode ? .green : colors.secondaryText)
                    .symbolEffect(.pulse, isActive: isConversationMode)
            }
            
            // 输入框
            TextField("输入消息...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colors.inputBackground)
                }
                .foregroundColor(colors.primaryText)
                .focused(isFocused)
                .lineLimit(1...5)
            
            // 语音/发送按钮
            if text.isEmpty {
                Button(action: onVoice) {
                    Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle")
                        .font(.title2)
                        .foregroundColor(speechService.isRecording ? .red : colors.secondaryText)
                        .symbolEffect(.bounce, value: speechService.isRecording)
                }
            } else {
                Button(action: onSend) {
                    if isLoading {
                        ProgressView()
                            .tint(colors.primaryText)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                .disabled(isLoading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(colors.cardBackground)
    }
}

// MARK: - Chat ViewModel
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
            let errorMessage = ChatMessage(role: .assistant, content: "抱歉，发生了错误: \(error.localizedDescription)")
            messages.append(errorMessage)
        }
        
        isLoading = false
    }
    
    func clearMessages() {
        messages.removeAll()
    }
}

#Preview {
    ChatView()
        .environment(AppState())
        .environment(ThemeManager.shared)
}
