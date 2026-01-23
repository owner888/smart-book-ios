// ChatView.swift - AI 对话视图（支持多语言，类似 ChatGPT 的极简设计）

import SwiftUI

struct ChatView: View {
    @Environment(BookState.self) var bookState
    @Environment(ThemeManager.self) var themeManager
    @Environment(SpeechService.self) var speechService
    @Environment(TTSService.self) var ttsService
    @Environment(\.colorScheme) var systemColorScheme
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var isConversationMode = false
    @State private var showBookPicker = false
    @State private var showSettings = false
    @State private var showBookshelf = false
    @State private var scrollBottom = 120.0
    @State private var keyboardHeight: CGFloat = 0

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
            .environment(bookState)
            .environment(themeManager)
            .frame(width: 340)
            .background(colors.cardBackground)
        } content: {
            chatContent
        }
        .environmentObject(sideObser)
        .sheet(isPresented: $showBookPicker) {
            BookPickerView(colors: colors) { book in
                withAnimation {
                    bookState.selectedBook = book
                }
                showBookPicker = false
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(bookState)
                .environment(themeManager)
        }
        .sheet(isPresented: $showBookshelf) {
            BookshelfView()
                .environment(bookState)
                .environment(themeManager)
        }
        .onAppear {
            viewModel.bookState = bookState
        }
    }

    // MARK: - 主聊天内容

    var chatContent: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    colors.background.ignoresSafeArea()
                    VStack(spacing: 0) {
                        // 聊天内容区域
                        InputToolBarView(
                            viewModel: viewModel,
                            inputText: $inputText,
                            content: {
                                VStack(spacing: 0) {
                                    if let book = bookState.selectedBook {
                                        BookContextBar(
                                            book: book,
                                            colors: colors
                                        ) {
                                            withAnimation {
                                                bookState.selectedBook = nil
                                            }
                                        }
                                    }
                                    // 对话列表（始终显示，无论是否选择书籍）
                                    if viewModel.messages.isEmpty {
                                        Spacer()
                                        if bookState.books.isEmpty {
                                            EmptyStateView(
                                                colors: colors,
                                                onAddBook: {
                                                    showBookPicker = true
                                                }
                                            )
                                        } else {
                                            EmptyChatStateView(
                                                colors: colors,
                                                onAddBook: {
                                                    showBookPicker = true
                                                }
                                            )
                                        }
                                        Color.clear.frame(height: 70)
                                        Spacer()
                                    } else {
                                        ZStack(alignment: .bottom) {
                                            // 有消息时显示对话列表
                                            ScrollViewReader { scrollProxy in
                                                let _ =
                                                    viewModel.scrollProxy =
                                                    scrollProxy
                                                ScrollView {
                                                    LazyVStack(spacing: 12) {
                                                        ForEach(
                                                            viewModel.messages
                                                        ) { message in
                                                            MessageBubble(
                                                                message:
                                                                    message,
                                                                colors: colors
                                                            )
                                                            .id(message.id)
                                                        }
                                                    }
                                                    .padding(.horizontal, 18)
                                                    .padding(.vertical, 8)
                                                    GeometryReader {
                                                        currentProxy in
                                                        Color.clear.frame(
                                                            height: 120
                                                        ).onChange(
                                                            of:
                                                                currentProxy
                                                                .frame(
                                                                    in: .global
                                                                ).maxY,
                                                            {
                                                                oldValue,
                                                                newValue in
                                                                let height =
                                                                    proxy.size
                                                                    .height
                                                                    + proxy
                                                                    .safeAreaInsets
                                                                    .top
                                                                    - keyboardHeight
                                                                    + 6

                                                                viewModel
                                                                    .showScrollToBottom =
                                                                    newValue
                                                                    > height
                                                            }
                                                        ).id("bottomAnchor")
                                                    }.frame(height: 120)
                                                    Color.clear.frame(
                                                        height: scrollBottom
                                                    )
                                                }
                                                .onChange(
                                                    of: viewModel
                                                        .questionMessageId
                                                ) {
                                                    if let messageId = viewModel
                                                        .questionMessageId
                                                    {
                                                        scrollBottom = max(
                                                            0,
                                                            proxy.size.height
                                                                - 280
                                                        )
                                                        // 延迟一点让UI更新完成
                                                        DispatchQueue.main
                                                            .asyncAfter(
                                                                deadline: .now()
                                                                    + 0.1
                                                            ) {
                                                                withAnimation {
                                                                    scrollProxy
                                                                        .scrollTo(
                                                                            messageId,
                                                                            anchor:
                                                                                .top
                                                                        )
                                                                }
                                                            }
                                                    }
                                                }
                                            }
                                            colors.background.frame(height: 10)
                                        }
                                    }
                                }
                            },
                            onSend: sendMessage,
                            keyboardHeightChanged: { value in
                                keyboardHeight = value
                            }
                        )
                        colors.background.frame(
                            height: proxy.safeAreaInsets.bottom
                        )
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L("chat.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { sideObser.jumpToPage(0) }) {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // 右侧更多菜单按钮
                    Menu {
                        Button(action: { showBookPicker = true }) {
                            Label(
                                L("chat.menu.selectBook"),
                                systemImage: "book"
                            )
                        }

                        Divider()

                        Button(action: { viewModel.clearMessages() }) {
                            Label(
                                L("chat.menu.clearHistory"),
                                systemImage: "trash"
                            )
                        }
                        .disabled(viewModel.messages.isEmpty)

                        Button(action: { exportConversation() }) {
                            Label(
                                L("chat.menu.exportChat"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .disabled(viewModel.messages.isEmpty)

                        Divider()

                        Button(action: { showSettings = true }) {
                            Label(
                                L("chat.menu.settings"),
                                systemImage: "gearshape"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
    }

    // MARK: - 消息发送和处理

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

            if isConversationMode,
                let lastMessage = viewModel.messages.last,
                lastMessage.role == .assistant
            {
                await ttsService.speak(lastMessage.content)
                startVoiceInput()
            }
        }
    }

    func toggleVoiceInput() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            startVoiceInput()
        }
    }

    func startVoiceInput() {
        speechService.startRecording { result in
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
            speechService.stopRecording()
            ttsService.stop()
        }
    }

    func exportConversation() {
        // 生成对话文本
        var exportText = "# Chat Export\n\n"

        for message in viewModel.messages {
            let role = message.role == .user ? "User" : "AI"
            let timestamp = message.timestamp.formatted(
                date: .abbreviated,
                time: .shortened
            )
            exportText +=
                "**\(role)** (\(timestamp)):\n\(message.content)\n\n---\n\n"
        }

        // 使用系统分享
        let activityVC = UIActivityViewController(
            activityItems: [exportText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first
            as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
        .environment(BookState())
        .environment(ThemeManager.shared)
}
