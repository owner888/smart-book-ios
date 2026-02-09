// ChatView.swift - AI 对话视图（支持多语言，类似 ChatGPT 的极简设计）

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(\.diContainer) private var container
    @Environment(BookState.self) var bookState
    @Environment(BookService.self) var bookService
    @Environment(ThemeManager.self) var themeManager
    @EnvironmentObject var ttsService: TTSService
    @Environment(AssistantService.self) var assistantService
    @Environment(ModelService.self) var modelService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var systemColorScheme
    @StateObject private var viewModel: ChatViewModel
    @State private var historyService: ChatHistoryService?
    
    // ✅ 使用 DI 容器创建 ViewModel
    init() {
        let container = DIContainer.shared
        _viewModel = StateObject(wrappedValue: container.makeChatViewModel())
    }
    @State private var inputText = ""
    @State private var showBookPicker = false
    @State private var showSettings = false
    @State private var showBookImporter = false
    @State private var showBookshelf = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var uploadProgress: Double = 0
    @State private var isUploading = false
    @State private var messageHeights = [UUID: CGFloat]()
    @State private var scrollViewFrame = CGRect.zero
    @State private var headerSpacer = 0.0
    @State private var adaptationBottom: CGFloat?
    @State private var answerInitialHeight = 0.0
    @State private var lastAnchorPosition: CGFloat?
    @State private var showBookRequiredAlert = false  // 显示需要选择书籍的提示

    @FocusState private var isInputFocused: Bool
    @StateObject private var sideObser = ExpandSideObservable()
    @State private var splitVisibility: NavigationSplitViewVisibility = .all

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }

    private var sidebarView: some View {
        Group {
            if isPad {
                // iPad/macOS使用Journal风格侧边栏
                TabletSidebarView(
                    colors: colors,
                    historyService: historyService,
                    viewModel: viewModel,
                    onSelectChat: {},
                    onSelectBookshelf: {
                        showBookshelf = true
                    },
                    onSelectSettings: {
                        showSettings = true
                    }
                )
            } else {
                // iPhone使用传统侧边栏
                MobileSidebarView(
                    colors: colors,
                    historyService: historyService,
                    viewModel: viewModel,
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
            }
        }
        .environment(bookState)
        .environment(themeManager)
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 360)
        .background(colors.cardBackground)
    }

    var scrollViewHeight: CGFloat {
        return scrollViewFrame.height
    }

    var body: some View {
        Group {
            if isPad {
                NavigationSplitView(columnVisibility: $splitVisibility) {
                    sidebarView
                } detail: {
                    chatContent
                }
            } else {
                ExpandSideView {
                    sidebarView
                } content: {
                    chatContent
                }
                .environmentObject(sideObser)
            }
        }
        .fullScreenCover(isPresented: $showBookPicker) {
            BookPickerView(colors: colors) { book in
                handleBookSelection(book)
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
        .fileImporter(
            isPresented: $showBookImporter,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            Task {
                await handleBookImport(result)
            }
        }
        .overlay {
            if isUploading {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView(value: uploadProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                            .tint(.green)

                        Text("📤 \(uploadProgress < 0.01 ? "导入书籍中..." : "上传书籍中... \(Int(uploadProgress * 100))%")")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colors.cardBackground)
                    )
                }
            }
        }
        .onAppear {
            // ✅ 使用 DI 容器初始化历史服务
            if historyService == nil {
                historyService = container.makeChatHistoryService(modelContext: modelContext)
                viewModel.historyService = historyService

                // 如果有当前对话（从历史列表选择的），加载消息
                // 否则等待用户发送第一条消息时自动创建对话
                if let currentConversation = historyService?.currentConversation {
                    viewModel.loadCurrentConversation()
                    Logger.info("📖 加载现有对话: \(currentConversation.title)")
                } else {
                    Logger.info("✨ 准备新对话，等待用户发送第一条消息")
                }
            }

            // ✅ 使用 DI 容器初始化摘要服务
            if viewModel.summarizationService == nil {
                viewModel.summarizationService = container.makeSummarizationService(
                    threshold: viewModel.summarizationThreshold
                )
                Logger.info("✅ 摘要服务已初始化，阈值: \(viewModel.summarizationThreshold)")
            }

            viewModel.bookState = bookState
            viewModel.selectedAssistant = assistantService.currentAssistant
            viewModel.selectedModel = modelService.currentModel.id
        }
        .onChange(of: assistantService.currentAssistant) { _, newAssistant in
            viewModel.selectedAssistant = newAssistant
        }
        .onChange(of: modelService.currentModel) { _, newModel in
            viewModel.selectedModel = newModel.id
        }
        .alert("需要选择书籍", isPresented: $showBookRequiredAlert) {
            Button("取消", role: .cancel) { }
            Button("选择书籍") {
                showBookPicker = true
            }
        } message: {
            Text("使用此助手需要先选择一本书籍")
        }
    }

    // MARK: - 主聊天内容

    var chatContent: some View {
        NavigationStack {
            GeometryReader { proxy in
                viewModel.safeAreaBottom = proxy.safeAreaInsets.bottom
                return ZStack {
                    colors.background.ignoresSafeArea()
                    VStack(spacing: 0) {
                        // 聊天内容区域
                        InputToolBarView(
                            viewModel: viewModel,
                            inputText: $inputText,
                            content: {
                                ZStack(alignment: .top) {
                                    // 对话列表（始终显示，无论是否选择书籍）
                                    if viewModel.messages.isEmpty {
                                        VStack {
                                            Spacer()
                                            if bookState.books.isEmpty {
                                                EmptyStateView(
                                                    colors: colors,
                                                    onAddBook: {
                                                        showBookImporter = true
                                                    }
                                                )
                                            } else {
                                                EmptyChatStateView(
                                                    colors: colors,
                                                    onAddBook: {
                                                        showBookPicker = true
                                                    },
                                                    isDefaultChatAssistant: assistantService.currentAssistant.id == "chat"
                                                )
                                            }
                                            Spacer()
                                        }
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
                                                            ).onGeometryChange(
                                                                for: CGFloat
                                                                    .self,
                                                                of: { geo in
                                                                    geo.frame(
                                                                        in:
                                                                            .global
                                                                    ).height
                                                                },
                                                                action: {
                                                                    newValue in
                                                                    messageChangedSize(
                                                                        newValue,
                                                                        id:
                                                                            message
                                                                            .id
                                                                    )
                                                                }
                                                            )
                                                            .id(message.id)
                                                        }
                                                    }
                                                    Color.clear.frame(
                                                        height: viewModel
                                                            .scrollBottom
                                                    )
                                                    bottomAnchorView

                                                }.scrollClipDisabled()
                                                    .contentMargins(
                                                        .top,
                                                        headerSpacer,
                                                        for: .scrollContent
                                                    ).onGeometryChange(
                                                        for: CGRect.self,
                                                        of: { geo in
                                                            geo.frame(
                                                                in: .global
                                                            )
                                                        },
                                                        action: { newValue in
                                                            scrollViewFrame =
                                                                newValue
                                                            scrollViewChangedSize()
                                                        }
                                                    )
                                            }
                                        }
                                    }
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
                                            // 系统提示词显示（如果有）
                                            if !assistantService
                                                .currentAssistant.systemPrompt
                                                .isEmpty
                                            {
                                                AssistantPromptBar(
                                                    assistant: assistantService
                                                        .currentAssistant,
                                                    colors: colors
                                                )
                                            }
                                        }
                                    }.onGeometryChange(for: CGFloat.self) {
                                        geo in
                                        geo.frame(in: .global).height
                                    } action: { newValue in
                                        headerSpacer = newValue
                                    }
                                }
                            },
                            onSend: { sendMessage() },
                            keyboardHeightChanged: { value in
                                keyboardHeight = value
                            }
                        )
                        .environmentObject(sideObser)
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                    .onChange(
                        of: viewModel
                            .currentMessageId
                    ) {
                        if viewModel
                            .currentMessageId != nil
                        {
                            onSended()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L("chat.title"))
            .toolbar {
                // 收缩按钮（只在iPhone显示，iPad使用系统自带的）
                if !isPad {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            sideObser.jumpToPage(0)
                        }) {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // 新对话按钮（只在有消息时显示）
                        if !viewModel.messages.isEmpty {
                            Button(action: {
                                viewModel.startNewConversation()
                            }) {
                                Image(systemName: "square.and.pencil")
                            }
                        }

                        // 更多菜单按钮
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
    }

    var bottomAnchorView: some View {
        Color.clear.frame(
            height: 1
        ).id("bottomAnchor").onGeometryChange(
            for: CGRect.self,
            of: { geo in
                geo.frame(in: .global)
            },
            action: { newValue in
                if !viewModel.keyboardChanging {
                    if let lastPosition = lastAnchorPosition, abs(newValue.maxY - lastPosition) > 100 {
                        lastAnchorPosition = nil
                        return
                    }
                    let distance = newValue.maxY - scrollViewFrame.maxY
                    viewModel.showScrollToBottom = distance > 16
                    lastAnchorPosition = newValue.maxY
                }
            }
        )
        .onAppear {
            if !viewModel.keyboardChanging {
                viewModel.showScrollToBottom = false
            }
        }.onDisappear {
            if !viewModel.keyboardChanging {
                viewModel.showScrollToBottom = true
            }
        }
    }

    private func scrollViewChangedSize() {
        if !viewModel.showScrollToBottom {
            viewModel.scrollToBottom(animate: false)
        }
    }

    private func messageChangedSize(_ height: CGFloat, id: UUID) {
        messageHeights[id] = height
        if id == viewModel.answerMessageId,
            let bottom = adaptationBottom,
            viewModel.isLoading
        {
            viewModel.scrollBottom = max(bottom - height, 0)
        }
    }

    private func onSended() {
        adaptationBottom = nil
        answerInitialHeight = 0
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.25,
            execute: {
                if let messageId = viewModel.currentMessageId {
                    if messageHeights[messageId] != nil {
                        scrollToMessageTop(messageId)
                    } else {
                        viewModel.scrollToBottom(animate: false)
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.2,
                            execute: {
                                scrollToMessageTop(messageId)
                            }
                        )
                    }
                }
            }
        )
    }

    private func scrollToMessageTop(_ messageId: UUID) {
        if let height = messageHeights[messageId] {
            viewModel.scrollBottom = max(
                scrollViewHeight - height - headerSpacer - 30.0,
                0
            )
            adaptationBottom = viewModel.scrollBottom
            if let answerHeight = messageHeights[
                viewModel.answerMessageId
            ] {
                answerInitialHeight = answerHeight
                viewModel.scrollBottom -= answerHeight
            }
            withAnimation {
                viewModel.scrollProxy?.scrollTo(messageId, anchor: .top)
            }
        }
    }

    // MARK: - 消息发送和处理
    func sendMessage() {
        let text = inputText
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty

        // 至少需要文本或媒体之一
        guard hasText || !viewModel.mediaItems.isEmpty else { return }

        // 检查 Ask 或 Continue 助手是否已选择书籍
        let currentAssistantId = assistantService.currentAssistant.id
        let requiresBook = currentAssistantId == "ask" || currentAssistantId == "continue"
        
        if requiresBook && bookState.selectedBook == nil {
            // 显示提示，要求用户选择书籍
            showBookRequiredAlert = true
            return
        }

        // 保存媒体副本
        let mediaToSend = viewModel.mediaItems

        // 清空输入
        inputText = ""
        viewModel.mediaItems.removeAll()

        // 立即收起键盘
        hiddenKeyboard()
        isInputFocused = false

        Task {
            await viewModel.sendMessage(text, mediaItems: mediaToSend)
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
    
    // MARK: - 书籍选择处理
    func handleBookSelection(_ book: Book) {
        Task {
            do {
                try await bookService.selectBook(book) { progress in
                    DispatchQueue.main.async {
                        if progress > 0 {
                            isUploading = true
                            uploadProgress = progress
                        }
                    }
                }
                
                await MainActor.run {
                    isUploading = false
                    withAnimation {
                        bookState.selectedBook = book
                    }
                    showBookPicker = false
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                }
                Logger.error("选择书籍失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 书籍导入处理
    func handleBookImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            
            // 显示上传进度
            await MainActor.run {
                isUploading = true
                uploadProgress = 0
            }
            
            var importedCount = 0
            for url in urls {
                do {
                    let book = try bookService.importBook(from: url)
                    importedCount += 1
                    
                    // 导入成功后，上传并选择第一本书
                    if importedCount == 1 {
                        try await bookService.selectBook(book) { progress in
                            DispatchQueue.main.async {
                                uploadProgress = progress
                            }
                        }
                        
                        await MainActor.run {
                            withAnimation {
                                bookState.selectedBook = book
                            }
                        }
                    }
                } catch {
                    Logger.error("导入书籍失败: \(error.localizedDescription)")
                }
            }
            
            // 重新加载书籍列表
            if importedCount > 0 {
                await bookState.loadBooks(using: bookService)
            }
            
            await MainActor.run {
                isUploading = false
            }
            
        case .failure(let error):
            Logger.error("选择文件失败: \(error.localizedDescription)")
            await MainActor.run {
                isUploading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
        .environment(BookState())
        .environment(ThemeManager.shared)
}
