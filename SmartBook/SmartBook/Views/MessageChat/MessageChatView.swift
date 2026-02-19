//
//  MessageChatView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/7.
//  Refactored: XIB → pure code
//

import Combine
import SwiftUI
import UIKit

enum MessageChatAction {
    case sendMessage
    case topFunction(_ event: MenuConfig.TopFunctionType)
    case popover(_ action: MessagePopoverAction, frame: CGRect)
    case addBook(hasBooks: Bool)  // true = 已有书籍，选择书籍；false = 无书籍，导入书籍
    case deselectBook  // 取消选择书籍
}

enum MessagePopoverAction {
    case openMedia
    case assistant
    case chooseModel
}

// 纯代码实现，不再依赖 MessageChatView.xib
class MessageChatView: UIView {
    var viewModel: ChatViewModel?
    var action: ((MessageChatAction) -> Void)?

    // MARK: - 纯代码属性（替代 @IBOutlet）
    private var bottomConstraint: NSLayoutConstraint!
    private var inputBar: InputToolView!
    private var tableView: UITableView!
    private var bottomBtn: UIButton!
    private var topView: MessageInputTopView?
    private var mainView: UIView!
    private var emptyBgView: UIView!

    private var cancellables = Set<AnyCancellable>()
    private var currentIdCancelables = Set<AnyCancellable>()
    private var messages = [ChatMessage]()
    private var messageHeights = [UUID: CGFloat]()

    private var adaptationBottom: CGFloat?
    private var originBottom: CGFloat?
    private let themeManager = ThemeManager.shared
    private var keyboardIsChanging = false
    private var emptyStateView: UIEmptyStateView?
    private var bookContextBar: UIBookContextBar?
    private var assistantPromptBar: UIAssistantPromptBar?
    private var headerStack: UIStackView!
    private var tableViewTopConstraint: NSLayoutConstraint!
    private var emptyBgViewTopConstraint: NSLayoutConstraint!
    private var safeAreaBottom: CGFloat = 0.0
    private var scrollingTop = false

    /// 当前选中的书籍
    var selectedBook: Book? {
        didSet {
            // 仅在书籍实际变化时才重建顶部栏
            if oldValue?.id != selectedBook?.id {
                updateHeaderBars()
            }
        }
    }

    /// 当前助手（用于显示系统提示词栏）
    var currentAssistant: Assistant? {
        didSet {
            // 仅在助手 ID 或系统提示词变化时才重建顶部栏
            if oldValue?.id != currentAssistant?.id || oldValue?.systemPrompt != currentAssistant?.systemPrompt {
                updateHeaderBars()
            }
        }
    }

    /// 是否已有书籍（参考 SwiftUI: bookState.books.isEmpty）
    var hasBooks: Bool = false {
        didSet {
            if hasBooks != oldValue {
                updateEmptyStateView()
            }
        }
    }

    var aiFunction: MenuConfig.AIModelFunctionType? {
        didSet {
            if let function = aiFunction {
                inputBar.aiFunction = function
            }
        }
    }

    var assistant: MenuConfig.AssistantType? {
        didSet {
            if let newValue = assistant {
                inputBar.assistant = newValue

                // 助手切换时更新空状态视图（参考 SwiftUI: isDefaultChatAssistant）
                updateEmptyStateView()
            }
        }
    }

    private var colors: ThemeColors {
        let colorScheme =
            traitCollection.userInterfaceStyle == .dark
            ? ColorScheme.dark : .light
        return themeManager.colors(for: colorScheme)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
        setUpUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
        setUpUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 纯代码构建 UI（替代 XIB）

    private func buildUI() {
        backgroundColor = .clear

        // === mainView ===
        mainView = UIView()
        mainView.backgroundColor = .clear
        mainView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainView)

        // === emptyBgView ===
        emptyBgView = UIView()
        emptyBgView.backgroundColor = .clear
        emptyBgView.translatesAutoresizingMaskIntoConstraints = false
        mainView.addSubview(emptyBgView)

        // === tableView ===
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false

        mainView.addSubview(tableView)

        // === topView (MessageInputTopView) ===
        topView = MessageInputTopView()
        topView!.backgroundColor = .clear
        topView!.translatesAutoresizingMaskIntoConstraints = false
        mainView.addSubview(topView!)

        // === bottomBtn (滚动到底部按钮) ===
        bottomBtn = UIButton(type: .system)
        bottomBtn.isHidden = true
        bottomBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomBtn.backgroundColor = UIColor(named: "ApprBlackColor") ?? .black
        bottomBtn.tintColor = UIColor(named: "ApprWhiteColor") ?? .white
        var btnConfig = UIButton.Configuration.plain()
        btnConfig.image = UIImage(systemName: "chevron.down")
        bottomBtn.configuration = btnConfig
        bottomBtn.layer.cornerRadius = 16
        bottomBtn.clipsToBounds = true
        bottomBtn.addTarget(self, action: #selector(scrollToBottomAction), for: .touchUpInside)
        mainView.addSubview(bottomBtn)

        // === inputBar (InputToolView) ===
        inputBar = InputToolView()
        inputBar.backgroundColor = .clear
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inputBar)

        // === 约束 ===
        // bottomConstraint: inputBar.bottom = self.bottom（稍后被 keyboardLayoutGuide 替代）
        bottomConstraint = inputBar.bottomAnchor.constraint(equalTo: bottomAnchor)

        // 存储可变的 top 约束（bookContextBar 出现时需要调整）
        tableViewTopConstraint = tableView.topAnchor.constraint(equalTo: mainView.topAnchor)
        emptyBgViewTopConstraint = emptyBgView.topAnchor.constraint(equalTo: mainView.topAnchor)

        NSLayoutConstraint.activate([
            // mainView: safeArea 约束
            mainView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            mainView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            mainView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            mainView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

            // emptyBgView: top/leading/trailing 跟随 mainView
            emptyBgViewTopConstraint,
            emptyBgView.leadingAnchor.constraint(equalTo: mainView.leadingAnchor),
            emptyBgView.trailingAnchor.constraint(equalTo: mainView.trailingAnchor),

            // tableView: mainView 内部，左右各 15pt padding
            tableViewTopConstraint,
            tableView.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 15),
            tableView.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -15),
            tableView.bottomAnchor.constraint(equalTo: mainView.bottomAnchor),

            // topView: 底部对齐 mainView，高度 50，左右 12pt
            topView!.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 12),
            topView!.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -12),
            topView!.bottomAnchor.constraint(equalTo: mainView.bottomAnchor, constant: -6),
            topView!.heightAnchor.constraint(equalToConstant: 50),

            // emptyBgView 底部到 topView 上方 50pt
            emptyBgView.bottomAnchor.constraint(equalTo: topView!.topAnchor, constant: -50),

            // bottomBtn: 右下角
            bottomBtn.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -20),
            bottomBtn.bottomAnchor.constraint(equalTo: mainView.bottomAnchor, constant: -6),
            bottomBtn.widthAnchor.constraint(equalToConstant: 32),
            bottomBtn.heightAnchor.constraint(equalToConstant: 32),

            // inputBar: 左右各 15pt（safeArea），低优先级高度
            inputBar.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 15),
            inputBar.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -15),
            bottomConstraint,
        ])

        // inputBar 高度低优先级约束
        let heightConstraint = inputBar.heightAnchor.constraint(equalToConstant: 80)
        heightConstraint.priority = .defaultLow
        heightConstraint.isActive = true
    }

    func setUpUI() {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        safeAreaBottom = scene?.windows.first?.safeAreaInsets.bottom ?? 0
        self.clipsToBounds = true

        // 使用 class 注册（不再使用 XIB nib）
        tableView.register(CommonChatCell.self, forCellReuseIdentifier: "commonChat")
        tableView.register(FootAdapterCell.self, forCellReuseIdentifier: "foot")
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self

        // 启用自动高度
        tableView.estimatedRowHeight = 20
        tableView.contentInset.bottom = 60  // 底部留出 60pt 空间
        tableView.scrollIndicatorInsets.bottom = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.reloadData()
        tableView.clipsToBounds = false

        inputBar.send = { [weak self] in
            self?.action?(.sendMessage)
        }
        inputBar.showPopover = { [weak self] (type, view) in
            guard let self = self else { return }
            let frame = view.convert(view.bounds, to: self)
            self.action?(.popover(type, frame: frame))
        }

        topView?.function = { [weak self] event in
            self?.action?(.topFunction(event))
        }

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
            (self: Self, previousTraitCollection: UITraitCollection) in
            self.tableView.reloadData()
        }

        // 键盘跟随
        bottomConstraint.isActive = false
        let keyboardConstraint = inputBar.bottomAnchor.constraint(
            equalTo: self.keyboardLayoutGuide.topAnchor,
            constant: 0
        )
        keyboardConstraint.isActive = true

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let userInfo = notification.userInfo,
                let keyboardFrame = userInfo[
                    UIResponder.keyboardFrameEndUserInfoKey
                ] as? NSValue,
                let viewModel = self.viewModel
            else { return }
            self.keyboardIsChanging = true
            let keyboardHeight = keyboardFrame.cgRectValue.height
            self.originBottom = viewModel.scrollBottom
            if viewModel.scrollBottom > keyboardHeight {
                viewModel.scrollBottom -= (keyboardHeight - self.safeAreaBottom)
                self.reloadBottom()
            } else if viewModel.scrollBottom > 30 {
                viewModel.scrollBottom = 30
                self.reloadBottom()
                self.onKeyboardFrameChange(notification)
            } else {
                self.onKeyboardFrameChange(notification)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.keyboardIsChanging = false
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let bottom = self.originBottom {
                self.viewModel?.scrollBottom = bottom
                self.reloadBottom()
                self.onKeyboardFrameChange(notification)
            }
            self.originBottom = nil
            self.keyboardIsChanging = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.keyboardIsChanging = false
            }
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapEvent))
        tapGesture.cancelsTouchesInView = false  // 不拦截子视图（UIButton）的点击
        mainView.addGestureRecognizer(tapGesture)
        createEmptyStateView()
    }

    // MARK: - 数据绑定
    func bind(to viewModel: ChatViewModel) {
        self.viewModel = viewModel
        inputBar.bind(to: viewModel)
        viewModel.$messages.receive(on: DispatchQueue.main).sink {
            [weak self] newMessages in
            guard let self = self else { return }
            if !newMessages.isEmpty {
                self.topView?.isHidden = true
            }
            let oldMessages = self.messages
            self.messages = newMessages
            // 空状态管理：根据消息数量显示/隐藏 emptyBgView 和 emptyStateView
            self.emptyBgView.isHidden = !newMessages.isEmpty

            if !newMessages.isEmpty {
                self.emptyStateView?.removeFromSuperview()
                self.emptyStateView = nil
            }

            // 智能更新：根据变化类型选择最小更新策略
            self.smartReloadTable(oldMessages: oldMessages, newMessages: newMessages)

        }.store(in: &cancellables)
        viewModel.$currentMessageId.receive(on: DispatchQueue.main).sink {
            [weak self] messageId in
            guard let self = self else { return }
            self.onSended()
        }.store(in: &currentIdCancelables)
    }

    /// 智能表格更新：避免流式更新时全量 reloadData
    private func smartReloadTable(oldMessages: [ChatMessage], newMessages: [ChatMessage]) {
        // 空 → 有消息：全量刷新
        if oldMessages.isEmpty && !newMessages.isEmpty {
            tableView.reloadData()
            return
        }

        // 有消息 → 空：全量刷新（清空对话）
        if !oldMessages.isEmpty && newMessages.isEmpty {
            tableView.reloadData()
            return
        }

        // 新增了消息（发送用户消息 或 创建 AI 占位消息）
        if newMessages.count > oldMessages.count {
            let newIndexPaths = (oldMessages.count..<newMessages.count).map {
                IndexPath(row: $0, section: 0)
            }
            tableView.insertRows(at: newIndexPaths, with: .none)
            return
        }

        // 消息数量减少（删除消息）：全量刷新
        if newMessages.count < oldMessages.count {
            tableView.reloadData()
            return
        }

        // 消息数量相同 → 内容更新（流式更新 AI 回复）
        if newMessages.count == oldMessages.count && !newMessages.isEmpty {
            let lastIndex = newMessages.count - 1
            let lastOld = oldMessages[lastIndex]
            let lastNew = newMessages[lastIndex]

            // 只有内容或状态变化时才更新
            if lastOld.content != lastNew.content
                || lastOld.isStreaming != lastNew.isStreaming
                || lastOld.thinking != lastNew.thinking
                || lastOld.tools?.count != lastNew.tools?.count
            {
                let indexPath = IndexPath(row: lastIndex, section: 0)

                // 流式更新时：直接更新可见 cell 内容，避免 reloadRows 导致闪屏
                if lastNew.isStreaming,
                    let cell = tableView.cellForRow(at: indexPath) as? CommonChatCell
                {
                    cell.configure(lastNew, assistant: nil, colors: colors)
                    // 通知 tableView 重新计算高度（不重建 cell）
                    UIView.performWithoutAnimation {
                        tableView.beginUpdates()
                        tableView.endUpdates()
                    }
                } else {
                    // 非流式（如 isStreaming → false）：用 reloadRows 完整刷新
                    tableView.reloadRows(at: [indexPath], with: .none)
                }
                return
            }
        }
    }

    @objc func tapEvent() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    func onKeyboardFrameChange(_ notification: Notification) {
        if bottomBtn.isHidden {
            guard let userInfo = notification.userInfo,
                let duration = userInfo[
                    UIResponder.keyboardAnimationDurationUserInfoKey
                ] as? Double,
                let curveRaw = userInfo[
                    UIResponder.keyboardAnimationCurveUserInfoKey
                ] as? Int
            else { return }
            let animationOptions = UIView.AnimationOptions(
                rawValue: UInt(curveRaw << 16)
            )
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [animationOptions, .beginFromCurrentState],
                animations: {
                    self.scrollToBottom(animated: false)
                },
                completion: nil
            )
        }
    }

    /// 创建空状态视图（首次加载或消息清空时调用）
    private func createEmptyStateView() {
        if emptyStateView == nil {
            let view = UIEmptyStateView(frame: CGRect.zero)
            view.translatesAutoresizingMaskIntoConstraints = false
            emptyBgView.addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: emptyBgView.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: emptyBgView.centerYAnchor),
            ])

            let isChat = assistant == .chat
            let currentHasBooks = hasBooks
            view.configure(
                colors: colors,
                hasBooks: currentHasBooks,
                onAddBook: { [weak self] in
                    guard let self = self else { return }
                    self.action?(.addBook(hasBooks: currentHasBooks))
                },
                isDefaultChatAssistant: isChat
            )

            emptyStateView = view

            // 空状态时：将 emptyBgView 提到 tableView 前面，确保按钮可点击
            mainView.bringSubviewToFront(emptyBgView)
        }
    }

    // MARK: - 顶部栏管理（BookContextBar + AssistantPromptBar）

    /// headerStack 底部约束到 tableView/emptyBgView 的 top
    private var tableViewToHeaderConstraint: NSLayoutConstraint?
    private var emptyBgToHeaderConstraint: NSLayoutConstraint?

    private func updateHeaderBars() {
        // 移除旧约束和 headerStack
        tableViewToHeaderConstraint?.isActive = false
        emptyBgToHeaderConstraint?.isActive = false
        tableViewToHeaderConstraint = nil
        emptyBgToHeaderConstraint = nil
        headerStack?.removeFromSuperview()
        bookContextBar = nil
        assistantPromptBar = nil

        var headerViews = [UIView]()

        // 1. BookContextBar（选中书籍时显示）
        if let book = selectedBook {
            let bar = UIBookContextBar()
            bar.configure(book: book) { [weak self] in
                self?.action?(.deselectBook)
            }
            bookContextBar = bar
            headerViews.append(bar)

            // 2. AssistantPromptBar（有系统提示词时显示，仅在选中书籍时）
            if let assistant = currentAssistant, !assistant.systemPrompt.isEmpty {
                let promptBar = UIAssistantPromptBar()
                promptBar.configure(assistant: assistant)
                // 不再需要 onHeightChanged 回调
                assistantPromptBar = promptBar
                headerViews.append(promptBar)
            }
        }

        if headerViews.isEmpty {
            headerStack = nil
            // 恢复原始 top 约束
            tableViewTopConstraint.constant = 0
            emptyBgViewTopConstraint.constant = 0
        } else {
            // 创建 headerStack
            let stack = UIStackView(arrangedSubviews: headerViews)
            stack.axis = .vertical
            stack.spacing = 0
            stack.translatesAutoresizingMaskIntoConstraints = false
            mainView.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: mainView.topAnchor),
                stack.leadingAnchor.constraint(equalTo: mainView.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: mainView.trailingAnchor),
            ])
            headerStack = stack

            // 禁用原始的 top 约束，改用 headerStack.bottom 驱动
            tableViewTopConstraint.isActive = false
            emptyBgViewTopConstraint.isActive = false

            // tableView.top = headerStack.bottom（自动跟随 headerStack 高度变化）
            let tvConstraint = tableView.topAnchor.constraint(equalTo: stack.bottomAnchor)
            tvConstraint.isActive = true
            tableViewToHeaderConstraint = tvConstraint

            let emptyConstraint = emptyBgView.topAnchor.constraint(equalTo: stack.bottomAnchor)
            emptyConstraint.isActive = true
            emptyBgToHeaderConstraint = emptyConstraint
        }

        UIView.animate(withDuration: 0.25) {
            self.mainView.layoutIfNeeded()
        }
    }

    /// 更新空状态视图（助手切换或书籍状态变化时调用）
    private func updateEmptyStateView() {
        guard let emptyStateView = emptyStateView else { return }

        let isChat = assistant == .chat
        let currentHasBooks = hasBooks
        emptyStateView.configure(
            colors: colors,
            hasBooks: currentHasBooks,
            onAddBook: { [weak self] in
                guard let self = self else { return }
                self.action?(.addBook(hasBooks: currentHasBooks))
            },
            isDefaultChatAssistant: isChat
        )
    }

    @objc func scrollToBottomAction() {
        scrollToBottom(animated: true)
    }

    private func scrollToBottom(animated: Bool) {
        if !messages.isEmpty {
            let total = tableView.numberOfRows(inSection: 0)
            let index = IndexPath(row: messages.count - 1, section: 0)
            if index.row < total {
                self.tableView.scrollToRow(
                    at: index,
                    at: .bottom,
                    animated: animated
                )
            }
        }
    }

    private func messageChangedSize(_ height: CGFloat, id: UUID) {
        messageHeights[id] = height
        guard let viewModel = viewModel else { return }
        if id == viewModel.answerMessageId,
            viewModel.isLoading
        {
            var bottom: CGFloat?
            if let adaptatio = adaptationBottom {
                bottom = adaptatio
            } else {
                if let questionId = viewModel.currentMessageId,
                    let questionHeight = messageHeights[questionId]
                {
                    bottom = max(
                        self.tableView.frame.height - questionHeight - 28.0,
                        0
                    )
                    adaptationBottom = bottom
                }
            }
            if let bottom = bottom {
                let offset = max(bottom - height, 0)
                if abs(viewModel.scrollBottom - offset) > 10 || (viewModel.scrollBottom > 0 && offset == 0) {
                    viewModel.scrollBottom = offset
                    reloadBottom()
                }
            }

            DispatchQueue.main.async { [weak self] in
                self?.detectScrolledToBottom()
            }
        }
    }

    private func onSended() {
        adaptationBottom = nil
        guard let viewModel = viewModel else {
            return
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.25,
            execute: { [weak self] in
                if let messageId = viewModel.currentMessageId {
                    if self?.messageHeights[messageId] != nil {
                        self?.scrollToMessageTop(messageId)
                    } else {
                        self?.scrollToBottom(animated: false)
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.2,
                            execute: { [weak self] in
                                self?.scrollToMessageTop(messageId)
                            }
                        )
                    }
                }
            }
        )
    }

    private func scrollToMessageTop(_ messageId: UUID) {
        guard let viewModel = viewModel,
            let answerMessageId = viewModel.answerMessageId
        else {
            return
        }
        if let height = messageHeights[messageId] {
            let bottom = max(
                self.tableView.frame.height - height - 28.0,
                0
            )
            viewModel.scrollBottom = bottom
            adaptationBottom = bottom
            if let answerHeight = messageHeights[answerMessageId] {
                viewModel.scrollBottom -= answerHeight
            }
            reloadBottom()
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.1,
                execute: { [weak self] in
                    self?.scrollToAnswerMessage()
                }
            )
        }
    }

    private func scrollToAnswerMessage() {
        if let index = messages.firstIndex(where: {
            $0.id == viewModel?.answerMessageId
        }) {
            scrollingTop = true
            let indexPath = IndexPath(row: index, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.5,
                execute: { [weak self] in
                    self?.scrollingTop = false
                }
            )
        }
    }

    private func reloadBottom() {
        if let space = viewModel?.scrollBottom {
            // 保持至少 60pt 底部间距
            let bottomInset = max(space, 60)
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        }
    }

    func detectScrolledToBottom() {
        if !keyboardIsChanging && !scrollingTop {
            tableView.layoutIfNeeded()
            let inset = tableView.contentInset.bottom
            let offset = tableView.contentOffset.y + tableView.frame.size.height
            let contentHeight = tableView.contentSize.height

            let effectiveContentHeight = contentHeight > 0 ? contentHeight + inset : tableView.frame.size.height

            let isAtBottom = offset > effectiveContentHeight - 20
            bottomBtn.isHidden = isAtBottom
            print("== scroll offset: \(offset), content height: \(effectiveContentHeight)")
        }
    }
}

extension MessageChatView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == self.tableView {
            detectScrolledToBottom()
        }
    }
}

extension MessageChatView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int)
        -> Int
    {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        if let cell = tableView.dequeueReusableCell(
            withIdentifier: "commonChat"
        ) as? CommonChatCell {
            cell.onChangedSized = { [weak self] (message, height) in
                if let id = message?.id {
                    self?.messageChangedSize(height, id: id)
                }
            }
            cell.configure(
                messages[indexPath.row],
                assistant: nil,
                colors: colors
            )
            return cell
        }
        return UITableViewCell()
    }

    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private class FootAdapterCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
