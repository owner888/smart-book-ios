//
//  MessageContentView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/9.
//

import SwiftUI
import UIKit

// ✅ 纯代码实现，不再依赖 MessageDisplayView.xib
class MessageDisplayView: UIView {

    var message: ChatMessage?
    var assistant: Assistant?
    var colors: ThemeColors = .dark
    var onChangedSized: ((ChatMessage?, CGFloat) -> Void)?

    // MARK: - 纯代码属性（替代 @IBOutlet）
    private var thinkingView: UIMessageThinkingView!
    private var toolsView: UIMessageToolsView!
    private var userTextHeight: NSLayoutConstraint!
    private var userTextViewWidth: NSLayoutConstraint!
    private var userMessageView: UIView!
    private var userTextView: CustomTextView!
    private var textViewHeight: NSLayoutConstraint!
    private var textView: CustomTextView!
    private var messageView: UIView!
    private var stackView: UIStackView!
    private var mainStackView: UIStackView!
    private var mediaContainerView: UIStackView?
    private var actionsView: UIMessageActionsView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    // MARK: - Setup（纯代码构建，替代 XIB）

    private func setUp() {
        backgroundColor = .clear

        // === 外层 stackView ===
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.alignment = .trailing  // 默认右对齐（用户消息）
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        // === 内层 mainStackView ===
        mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .equalSpacing
        mainStackView.alignment = .trailing
        mainStackView.spacing = 12
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(mainStackView)

        // === thinkingView ===
        thinkingView = UIMessageThinkingView()
        thinkingView.isHidden = true
        thinkingView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.addArrangedSubview(thinkingView)

        // === toolsView（工具使用胶囊）===
        toolsView = UIMessageToolsView()
        toolsView.isHidden = true
        toolsView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.addArrangedSubview(toolsView)

        // === mediaContainerView（图片容器）===
        let mediaContainer = UIStackView()
        mediaContainer.axis = .horizontal
        mediaContainer.spacing = 10
        mediaContainer.alignment = .center
        mediaContainer.distribution = .fill
        mediaContainer.translatesAutoresizingMaskIntoConstraints = false
        mediaContainer.isHidden = true
        mainStackView.addArrangedSubview(mediaContainer)
        mediaContainerView = mediaContainer

        // === userMessageView（用户消息气泡）===
        userMessageView = UIView()
        userMessageView.backgroundColor = .clear
        userMessageView.translatesAutoresizingMaskIntoConstraints = false

        let userBubbleBg = UIView()
        userBubbleBg.translatesAutoresizingMaskIntoConstraints = false
        userBubbleBg.backgroundColor = .clear
        userMessageView.addSubview(userBubbleBg)

        userTextView = CustomTextView()
        userTextView.translatesAutoresizingMaskIntoConstraints = false
        userBubbleBg.addSubview(userTextView)

        // userTextView 约束（padding 12）
        userTextViewWidth = userTextView.widthAnchor.constraint(equalToConstant: 300)
        userTextHeight = userTextView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            userTextView.topAnchor.constraint(equalTo: userBubbleBg.topAnchor, constant: 12),
            userTextView.leadingAnchor.constraint(equalTo: userBubbleBg.leadingAnchor, constant: 12),
            userTextView.trailingAnchor.constraint(equalTo: userBubbleBg.trailingAnchor, constant: -12),
            userTextView.bottomAnchor.constraint(equalTo: userBubbleBg.bottomAnchor, constant: -12),
            userTextViewWidth,
            userTextHeight,

            userBubbleBg.topAnchor.constraint(equalTo: userMessageView.topAnchor),
            userBubbleBg.trailingAnchor.constraint(equalTo: userMessageView.trailingAnchor),
            userBubbleBg.bottomAnchor.constraint(equalTo: userMessageView.bottomAnchor),
        ])

        mainStackView.addArrangedSubview(userMessageView)

        // === messageView（AI 消息）===
        messageView = UIView()
        messageView.backgroundColor = .clear
        messageView.translatesAutoresizingMaskIntoConstraints = false

        let aiBubbleBg = UIView()
        aiBubbleBg.translatesAutoresizingMaskIntoConstraints = false
        aiBubbleBg.backgroundColor = .clear
        messageView.addSubview(aiBubbleBg)

        textView = CustomTextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        aiBubbleBg.addSubview(textView)

        textViewHeight = textView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: aiBubbleBg.topAnchor),
            textView.leadingAnchor.constraint(equalTo: aiBubbleBg.leadingAnchor, constant: 6),
            textView.trailingAnchor.constraint(equalTo: aiBubbleBg.trailingAnchor, constant: -6),
            textView.bottomAnchor.constraint(equalTo: aiBubbleBg.bottomAnchor),
            textViewHeight,

            aiBubbleBg.topAnchor.constraint(equalTo: messageView.topAnchor),
            aiBubbleBg.leadingAnchor.constraint(equalTo: messageView.leadingAnchor),
            aiBubbleBg.trailingAnchor.constraint(equalTo: messageView.trailingAnchor),
            aiBubbleBg.bottomAnchor.constraint(equalTo: messageView.bottomAnchor),
        ])

        mainStackView.addArrangedSubview(messageView)

        // === actionsView（复制等操作按钮，仅 AI 消息显示）===
        actionsView = UIMessageActionsView()
        actionsView.isHidden = true
        actionsView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.addArrangedSubview(actionsView)

        // === 外层约束 ===
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            {
                let c = stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
                c.priority = .defaultHigh
                return c
            }(),

            mainStackView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),

            // thinkingView 全宽
            thinkingView.leadingAnchor.constraint(equalTo: mainStackView.leadingAnchor),
            thinkingView.trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor),

            // mediaContainer 右对齐
            mediaContainer.trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor),

            // userMessageView 全宽（内部右对齐）
            userMessageView.leadingAnchor.constraint(equalTo: mainStackView.leadingAnchor),
            userMessageView.trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor),

            // messageView 全宽
            messageView.leadingAnchor.constraint(equalTo: mainStackView.leadingAnchor),
            messageView.trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor),
        ])

        // 配置 textView 属性
        configureTextView(textView)
        configureTextView(userTextView)
    }

    /// 显示用户消息中的媒体项（图片/文档），参考 SwiftUI MediaItemThumbnail 样式
    private func displayMediaItems(_ items: [MediaItem]?) {
        guard let container = mediaContainerView else { return }

        // 清除旧内容
        container.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let items = items, !items.isEmpty else {
            container.isHidden = true
            return
        }

        // 右对齐：先加一个弹性 Spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        container.addArrangedSubview(spacer)

        for item in items {
            switch item.type {
            case .image(let image):
                let imageView = createMediaImageView(image: image)
                container.addArrangedSubview(imageView)

            case .document(let url):
                let docView = createDocumentView(url: url)
                container.addArrangedSubview(docView)
            }
        }

        container.isHidden = false
    }

    /// 创建图片缩略图（110x110，圆角12，scaledToFill），与 SwiftUI MediaItemThumbnail 一致
    private func createMediaImageView(image: UIImage) -> UIView {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor(colors.secondaryText).withAlphaComponent(0.2).cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 110),
            imageView.heightAnchor.constraint(equalToConstant: 110),
        ])

        return imageView
    }

    /// 创建文档缩略图（110x110，圆角12，图标+文件名），与 SwiftUI MediaItemThumbnail 一致
    private func createDocumentView(url: URL) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(colors.secondaryText).withAlphaComponent(0.2).cgColor
        container.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(textStyle: .title2)
        let iconView = UIImageView(image: UIImage(systemName: "doc.fill", withConfiguration: iconConfig))
        iconView.tintColor = UIColor(colors.secondaryText)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = url.lastPathComponent
        nameLabel.font = .systemFont(ofSize: 10)
        nameLabel.textColor = UIColor(colors.secondaryText)
        nameLabel.numberOfLines = 2
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(nameLabel)
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 110),
            container.heightAnchor.constraint(equalToConstant: 110),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            nameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100),
        ])

        return container
    }

    func configureTextView(_ textView: CustomTextView?) {
        guard let textView = textView else {
            return
        }

        textView.isEditable = false  // 禁止编辑
        textView.isScrollEnabled = false  // 禁止滚动
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isSelectable = true  // 允许选择
        textView.delaysContentTouches = false
        textView.dataDetectorTypes = .link

        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )  // 允许水平压缩（换行）
        textView.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
    }

    func config(_ message: ChatMessage, assistant: Assistant?, colors: ThemeColors) {
        self.message = message
        self.assistant = assistant
        self.colors = colors
        displayMessageContent(message)

        if let thinking = message.thinking, !thinking.isEmpty {
            thinkingView?.thinking = thinking
            thinkingView?.colors = colors
            thinkingView?.isHidden = false
        } else {
            thinkingView?.isHidden = true
        }

        // ✅ 工具使用胶囊显示
        if let tools = message.tools, !tools.isEmpty {
            toolsView?.configure(tools: tools, colors: colors)
            toolsView?.isHidden = false
        } else {
            toolsView?.isHidden = true
        }

        // ✅ 复制按钮（仅 AI 消息且非流式时显示）
        if message.role == .assistant && !message.content.isEmpty && !message.isStreaming {
            actionsView?.configure(content: message.content, colors: colors)
            actionsView?.isHidden = false
        } else {
            actionsView?.isHidden = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onChangedSized?(message, self.frame.height)
    }

    /// 根据消息内容和角色显示文本和媒体，调整布局和样式
    private func displayMessageContent(_ message: ChatMessage) {
        if message.role == .user {
            guard let textView = userTextView else {
                return
            }
            stackView?.alignment = .trailing
            mainStackView?.alignment = .trailing
            messageView?.isHidden = true
            userMessageView?.isHidden = false

            // ✅ 显示用户消息附带的媒体（图片/文档）
            displayMediaItems(message.mediaItems)

            textView.font = UIFont.preferredFont(forTextStyle: .callout)
            textView.textColor = UIColor(colors.primaryText)
            textView.text = message.content
            let bgView = textView.superview
            bgView?.layer.masksToBounds = true
            bgView?.layer.cornerRadius = 16
            bgView?.backgroundColor = UIColor(colors.userBubble)
            textView.layoutIfNeeded()
            textView.invalidateIntrinsicContentSize()
            // 计算 attributedText 高度
            // ✅ 使用屏幕宽度作为后备，避免 frame 为 0 时一字一行
            let availableWidth = self.frame.size.width > 0 ? self.frame.size.width : UIScreen.main.bounds.width
            let maxBubbleWidth = availableWidth * 0.75  // 气泡最大宽度为屏幕 75%
            let fixedWidth = maxBubbleWidth - 24  // 减去左右 padding 12*2
            let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
            // ✅ 取实际文本宽度和最大宽度的较小值，但不小于 40
            userTextViewWidth?.constant = max(40, min(newSize.width, fixedWidth))
            userTextHeight?.constant = newSize.height

            // 高度需要包含媒体容器的高度
            let mediaHeight: CGFloat = (mediaContainerView?.isHidden == false) ? 122 : 0  // 110 + spacing
            onChangedSized?(message, newSize.height + 24 + mediaHeight)
        } else {
            guard let textView = textView else {
                return
            }
            stackView?.alignment = .leading
            mainStackView?.alignment = .leading
            userMessageView?.isHidden = true
            messageView?.isHidden = false

            // AI 消息不显示媒体容器
            displayMediaItems(nil)

            let content = MessageDisplayContent(
                message: message,
                colors: colors
            )
            let attributedString = content.markdownToAttributedString()
            textView.attributedText = attributedString

            textView.invalidateIntrinsicContentSize()
            // 计算 attributedText 高度
            textView.layoutIfNeeded()

            let textSize = textView.intrinsicContentSize
            textViewHeight?.constant = textSize.height
            //onChangedSized?(message, textSize.height)
        }
    }
}
