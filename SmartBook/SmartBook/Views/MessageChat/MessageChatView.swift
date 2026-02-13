//
//  MessageChatView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/7.
//

import Combine
import SwiftUI
import UIKit

enum MessageChatAction {
    case sendMessage
    case topFunction(_ event: MenuConfig.TopFunctionType)
    case popover(_ action: MessagePopoverAction, frame: CGRect)
}

enum MessagePopoverAction {
    case openMedia
    case assistant
    case chooseModel
}

class MessageChatView: UIView {
    var viewModel: ChatViewModel?
    var action: ((MessageChatAction) -> Void)?
    @IBOutlet weak private var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak private var inputBar: InputToolView!
    @IBOutlet weak private var tableView: UITableView!
    @IBOutlet weak private var bottomBtn: UIButton!
    @IBOutlet weak private var topView: MessageInputTopView?
    @IBOutlet weak private var mainView: UIView!
    @IBOutlet weak private var emptyBgView: UIView!
    private var cancellables = Set<AnyCancellable>()
    private var currentIdCancelables = Set<AnyCancellable>()
    private var messages = [ChatMessage]()
    private var messageHeights = [UUID: CGFloat]()

    private var adaptationBottom: CGFloat?
    private var originBottom: CGFloat?
    private let themeManager = ThemeManager.shared
    private var keyboardIsChanging = false
    private var emptyStateView: UIEmptyStateView?
    private var safeAreaBottom: CGFloat = 0.0
    private var reducedQuestionHeight = false
    
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
                
                // ✅ 助手切换时更新空状态视图
                let isChat = newValue == .chat
                emptyStateView?.configure(
                    colors: colors,
                    onAddBook: {
                        // TODO: 处理添加书籍
                    },
                    isDefaultChatAssistant: isChat
                )
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
        loadXib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func loadXib() {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: "MessageChatView", bundle: bundle)
        if let view = nib.instantiate(withOwner: self).first as? UIView {
            view.frame = self.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(view)
        }
        setUpUI()
    }

    func setUpUI() {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        safeAreaBottom = scene?.windows.first?.safeAreaInsets.bottom ?? 0
        self.clipsToBounds = true
        tableView.register(
            UINib(nibName: "CommonChatCell", bundle: nil),
            forCellReuseIdentifier: "commonChat"
        )
        tableView.register(FootAdapterCell.self, forCellReuseIdentifier: "foot")
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self

        // 启用自动高度
        tableView.estimatedRowHeight = 20
        tableView.rowHeight = UITableView.automaticDimension
        tableView.reloadData()
        tableView.clipsToBounds = false
        
        
        inputBar.send = {[weak self] in
            self?.topView?.isHidden = true
            self?.action?(.sendMessage)
        }
        inputBar.showPopover = {[weak self] (type, view) in
            guard let self = self else{return}
            let frame = view.convert(view.bounds, to: self)
            self.action?(.popover(type, frame: frame))
        }
        
        topView?.function = {[weak self] event in
            self?.action?(.topFunction(event))
        }

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
            (self: Self, previousTraitCollection: UITraitCollection) in
            self.tableView.reloadData()
        }

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
        ) { notification in
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
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: OperationQueue.main) { notification in
            if let bottom = self.originBottom {
                self.viewModel?.scrollBottom = bottom
                self.reloadBottom()
                self.onKeyboardFrameChange(notification)
            }
            self.originBottom = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                self.keyboardIsChanging = false
            })
        }
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.tableView.reloadData()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapEvent))
        mainView.addGestureRecognizer(tapGesture)
        createEmptyStateView()
    
    }

    func bind(to viewModel: ChatViewModel) {
        self.viewModel = viewModel
        inputBar.bind(to: viewModel)
        viewModel.$messages.receive(on: DispatchQueue.main).sink {
            [weak self] messages in
            guard let self = self else { return }
            self.messages = messages
            if !messages.isEmpty {
                self.emptyStateView?.removeFromSuperview()
                self.emptyStateView = nil
            }
            self.tableView.reloadData()

        }.store(in: &cancellables)
        viewModel.$currentMessageId.receive(on: DispatchQueue.main).sink {
            [weak self] messageId in
            guard let self = self else { return }
            self.onSended()
        }.store(in: &currentIdCancelables)


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
    
    private func createEmptyStateView() {
        if emptyStateView == nil {
            let view = UIEmptyStateView(frame: CGRect.zero)
            view.translatesAutoresizingMaskIntoConstraints = false
            emptyBgView.addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: emptyBgView.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: emptyBgView.centerYAnchor)
            ])
            
            // ✅ 配置空状态视图，传递助手类型
            let isChat = assistant == .chat
            view.configure(colors: colors, onAddBook: {
                // TODO: 处理添加书籍
            }, isDefaultChatAssistant: isChat)
            
            emptyStateView = view
        }
    }
    
    @IBAction func scrollToBottomAction() {
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
        guard let viewModel = viewModel else {return}
//        if let qMess = messageHeights[viewModel.currentMessageId!] {
//            print("==问题高度: \(qMess)")
//        }
//        if let messageId = viewModel.answerMessageId,
//            let answer = messageHeights[messageId] {
//            print("==回答高度: \(answer)")
//        }
        if id == viewModel.answerMessageId,
            viewModel.isLoading
        {
            var bottom: CGFloat?
            if let adaptatio = adaptationBottom {
                bottom = adaptatio
            } else {
                //如果没有获取到显示问题后的高度后,需要再获取一次.
                if let questionId = viewModel.currentMessageId,
                   let questionHeight = messageHeights[questionId] {
                    bottom = max(
                        self.tableView.frame.height - questionHeight - 28.0,
                        0
                    )
                    adaptationBottom = bottom
                }
            }
            //根据回答内容的高度逐步越少底部空余高度
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
        reducedQuestionHeight = false
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

    //滚到问题消息到顶部
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
                reducedQuestionHeight = true
                viewModel.scrollBottom -= answerHeight
            }
            reloadBottom()
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.2,
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
            let indexPath = IndexPath(row: index, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
        }

    }

    private func reloadBottom() {
        if let space = viewModel?.scrollBottom {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: space, right: 0)
        }
    }
    
    func detectScrolledToBottom() {
        if !keyboardIsChanging {
            tableView.layoutIfNeeded()
            let inset = tableView.contentInset.bottom
            let offset = tableView.contentOffset.y + tableView.frame.size.height
            let contentHeight = tableView.contentSize.height

            let effectiveContentHeight = contentHeight > 0 ? contentHeight + inset : tableView.frame.size.height

            let isAtBottom = offset > effectiveContentHeight - 20
            bottomBtn.isHidden = isAtBottom
            
//            print("== table view offset: \(offset), contentSize: \(effectiveContentHeight), frame: \(tableView.frame.size.height), isAtBottom: \(isAtBottom)")
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
