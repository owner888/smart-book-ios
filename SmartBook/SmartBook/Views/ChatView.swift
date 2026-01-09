// ChatView.swift - AI 对话视图（支持语音对话）

import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var isConversationMode = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 当前书籍提示
                    if let book = appState.selectedBook {
                        BookContextBar(book: book)
                    }
                    
                    // 消息列表
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
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
                        onSend: sendMessage,
                        onVoice: toggleVoiceInput,
                        onConversation: toggleConversationMode
                    )
                }
            }
            .navigationTitle("AI 对话")
            .navigationBarTitleDisplayMode(.inline)
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
            
            // 对话模式：自动播放 TTS
            if isConversationMode, let lastMessage = viewModel.messages.last, lastMessage.role == .assistant {
                await appState.ttsService.speak(lastMessage.content)
                // TTS 完成后继续监听
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
                // 对话模式：自动发送
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
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.fill")
                .foregroundColor(.green)
            
            Text("正在阅读: \(book.title)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Button {
                // 清除选择
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 消息气泡
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background {
                        if message.role == .user {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.8))
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .foregroundColor(.white)
                
                // 时间戳
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
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
    let onSend: () -> Void
    let onVoice: () -> Void
    let onConversation: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 对话模式按钮
            Button(action: onConversation) {
                Image(systemName: isConversationMode ? "waveform.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundColor(isConversationMode ? .green : .gray)
                    .symbolEffect(.pulse, isActive: isConversationMode)
            }
            
            // 输入框
            TextField("输入消息...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                }
                .focused(isFocused)
                .lineLimit(1...5)
            
            // 语音/发送按钮
            if text.isEmpty {
                Button(action: onVoice) {
                    Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle")
                        .font(.title2)
                        .foregroundColor(speechService.isRecording ? .red : .blue)
                        .symbolEffect(.bounce, value: speechService.isRecording)
                }
            } else {
                Button(action: onSend) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
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
        .background(.ultraThinMaterial)
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
        
        // 添加用户消息
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
}
