// ChatView.swift - AI 对话视图（支持多语言）

import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var isConversationMode = false
    @State private var showBookPicker = false
    @FocusState private var isInputFocused: Bool
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if let book = appState.selectedBook {
                        BookContextBar(book: book, colors: colors) {
                            withAnimation {
                                appState.selectedBook = nil
                            }
                        }
                    }
                    
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
            .navigationTitle(L("chat.title"))
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
                        Button(L("chat.selectBook"), systemImage: "book") {
                            showBookPicker = true
                        }
                        
                        if appState.selectedBook != nil {
                            Button(L("chat.deselectBook"), systemImage: "book.closed") {
                                withAnimation {
                                    appState.selectedBook = nil
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(L("chat.clearHistory"), systemImage: "trash", role: .destructive) {
                            viewModel.clearMessages()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(colors.primaryText)
                    }
                }
            }
            .sheet(isPresented: $showBookPicker) {
                BookPickerView(colors: colors) { book in
                    withAnimation {
                        appState.selectedBook = book
                    }
                    showBookPicker = false
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
                    .foregroundColor(colors.secondaryText)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(colors.cardBackground)
    }
}

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
            Button(action: onConversation) {
                Image(systemName: isConversationMode ? "waveform.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundColor(isConversationMode ? .green : colors.secondaryText)
                    .symbolEffect(.pulse, isActive: isConversationMode)
            }
            
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

#Preview {
    ChatView()
        .environment(AppState())
        .environment(ThemeManager.shared)
}
