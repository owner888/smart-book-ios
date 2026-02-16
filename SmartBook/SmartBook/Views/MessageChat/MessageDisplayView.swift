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
        guard let textView = textView else{
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
            thinkingView?.isHidden = false
        } else {
            thinkingView?.isHidden = true
        }
            
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        onChangedSized?(message,self.frame.height)
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
            userMessageView?.isHidden  = false
            
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
            
            let fixedWidth = self.frame.size.width - 30
            let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
            userTextViewWidth?.constant = newSize.width
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

final class UIMessageAssistantHeaderView: UIView {
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let avatarCircle: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        addSubview(stackView)

        avatarCircle.addSubview(avatarLabel)
        stackView.addArrangedSubview(avatarCircle)
        stackView.addArrangedSubview(nameLabel)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarCircle.widthAnchor.constraint(equalToConstant: 24),
            avatarCircle.heightAnchor.constraint(equalToConstant: 24),

            avatarLabel.centerXAnchor.constraint(
                equalTo: avatarCircle.centerXAnchor
            ),
            avatarLabel.centerYAnchor.constraint(
                equalTo: avatarCircle.centerYAnchor
            ),
        ])
    }

    func configure(assistant: Assistant, colors: ThemeColors) {
        avatarCircle.backgroundColor = UIColor(assistant.colorValue)
            .withAlphaComponent(0.2)
        avatarLabel.text = assistant.avatar
        nameLabel.text = assistant.name
        nameLabel.textColor = UIColor(colors.secondaryText)
    }
}

final class UIMessageThinkingView: UIView {
    
    // ✅ 纯代码实现，不再依赖 UIMessageThinkingView.xib
    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 16)
        let iv = UIImageView(image: UIImage(systemName: "brain.head.profile", withConfiguration: config))
        iv.tintColor = .systemPurple
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let label: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let chevronButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.right")
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    var thinking: String = "" {
        didSet {
            label.text = thinking
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }
    
    private func setUp() {
        layer.masksToBounds = true
        layer.cornerRadius = 6
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemPurple.withAlphaComponent(0.8).cgColor
        backgroundColor = UIColor.systemPurple.withAlphaComponent(0.04)
        
        addSubview(iconView)
        addSubview(label)
        addSubview(chevronButton)
        
        NSLayoutConstraint.activate([
            // 图标
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            
            // 标签
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: chevronButton.leadingAnchor, constant: -20),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            
            // 展开按钮
            chevronButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            chevronButton.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: 35),
            chevronButton.heightAnchor.constraint(equalToConstant: 35),
        ])
    }
}

final class UIMessageContentView: UIView {
    var message: ChatMessage?
    var colors = ThemeColors.dark
    var textView: CustomTextView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    func setUp() {
        textView = CustomTextView()
        textView.font = .systemFont(ofSize: 14)  // 根据需要调整字体大小
        textView.isEditable = false  // 禁止编辑
        textView.isScrollEnabled = false  // 禁止滚动
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isSelectable = true  // 允许选择
        textView.delaysContentTouches = false
        textView.dataDetectorTypes = .link
        self.addSubview(textView)

        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

    }

    func configure(_ message: ChatMessage, colors: ThemeColors) {
        self.message = message
        self.colors = colors
        if message.role == .user {
            textView.textColor = UIColor(colors.primaryText)
            textView.text = message.content
            textView.invalidateIntrinsicContentSize()
        } else {
            // 确保文本视图可以换行和调整大小
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

            let content = MessageDisplayContent(
                message: message,
                colors: colors
            )
            // 使用SelectableText实现真正的文本选择
            let attributedString = content.markdownToAttributedString()
            textView.attributedText = attributedString
            textView.invalidateIntrinsicContentSize()
        }

    }

}

final class UIMessageSourcesView: UIView {

    // MARK: - Properties
    private var sources: [RAGSource] = []
    private var isExpanded: Bool = false
    private var colors = ThemeColors.dark

    // MARK: - UI Components
    required override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        imageView.image = UIImage(
            systemName: "chevron.right",
            withConfiguration: config
        )
        imageView.tintColor = .label
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .medium)
        return label
    }()

    private let sourcesStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }()

    private var sourcesContainerHeightConstraint: NSLayoutConstraint?

    // MARK: - Initialization

    func config(
        sources: [RAGSource],
        colors: ThemeColors = .dark,
        isExpanded: Bool = false
    ) {
        self.sources = sources
        self.colors = colors
        self.isExpanded = isExpanded
        setupUI()
        updateAppearance()
    }

    

    private func setupUI() {
        addSubview(containerStack)

        // Header
        let headerStack = createHeaderStack()

        // Sources container
        let sourcesContainer = UIView()
        sourcesContainer.translatesAutoresizingMaskIntoConstraints = false
        sourcesContainer.addSubview(sourcesStackView)

        NSLayoutConstraint.activate([
            sourcesStackView.topAnchor.constraint(
                equalTo: sourcesContainer.topAnchor
            ),
            sourcesStackView.leadingAnchor.constraint(
                equalTo: sourcesContainer.leadingAnchor
            ),
            sourcesStackView.trailingAnchor.constraint(
                equalTo: sourcesContainer.trailingAnchor
            ),
            sourcesStackView.bottomAnchor.constraint(
                equalTo: sourcesContainer.bottomAnchor
            ),

            containerStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 8
            ),
            containerStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 8
            ),
            containerStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -8
            ),
            containerStack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -8
            ),
        ])

        containerStack.addArrangedSubview(headerStack)
        containerStack.addArrangedSubview(sourcesContainer)

        // Initially collapsed
        sourcesContainer.isHidden = true
        sourcesContainerHeightConstraint = sourcesContainer.heightAnchor
            .constraint(equalToConstant: 0)
        sourcesContainerHeightConstraint?.isActive = true

        setupBorderAndBackground()
    }

    private func createHeaderStack() -> UIStackView {
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        iconImageView.image = UIImage(
            systemName: "books.vertical",
            withConfiguration: config
        )
        iconImageView.tintColor = .green

        let headerStack = UIStackView(arrangedSubviews: [
            iconImageView, titleLabel, chevronImageView,
        ])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
        ])

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(headerTapped)
        )
        headerStack.isUserInteractionEnabled = true
        headerStack.addGestureRecognizer(tapGesture)

        return headerStack
    }

    private func setupBorderAndBackground() {
        let greenColor = UIColor.green

        layer.cornerRadius = 8
        clipsToBounds = true

        // Add border layer
        let borderLayer = CAShapeLayer()
        borderLayer.strokeColor = greenColor.withAlphaComponent(0.3).cgColor
        borderLayer.fillColor = greenColor.withAlphaComponent(0.05).cgColor
        borderLayer.lineWidth = 1
        borderLayer.path =
            UIBezierPath(roundedRect: bounds, cornerRadius: 8).cgPath
        borderLayer.frame = bounds
        layer.addSublayer(borderLayer)
    }

    private func updateAppearance() {
        titleLabel.text = L("chat.sources.title", sources.count)
        titleLabel.textColor = UIColor(colors.primaryText)
        rebuildSourcesStack()
        
    }

    private func rebuildSourcesStack() {
        sourcesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for source in sources.prefix(3) {
            let sourceView = createSourceRow(source: source)
            sourcesStackView.addArrangedSubview(sourceView)
        }
    }

    private func createSourceRow(source: RAGSource) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.green.withAlphaComponent(0.05)
        container.layer.cornerRadius = 6

        // Score percentage label
        let scoreLabel = UILabel()
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.text = "\(source.scorePercentage)%"
        scoreLabel.font = .systemFont(ofSize: 11, weight: .bold)
        scoreLabel.textColor = .green
        scoreLabel.textAlignment = .center

        // Score background (Capsule)
        let scoreContainer = UIView()
        scoreContainer.translatesAutoresizingMaskIntoConstraints = false
        scoreContainer.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        scoreContainer.layer.cornerRadius = 8

        // Source text
        let textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.text = source.text
        textLabel.font = .systemFont(ofSize: 12)
        textLabel.textColor = UIColor(colors.secondaryText)
        textLabel.numberOfLines = 3

        container.addSubview(scoreContainer)
        container.addSubview(scoreLabel)
        container.addSubview(textLabel)

        NSLayoutConstraint.activate([
            scoreContainer.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: 2
            ),
            scoreContainer.leadingAnchor.constraint(
                equalTo: container.leadingAnchor,
                constant: 2
            ),
            scoreContainer.bottomAnchor.constraint(
                equalTo: container.bottomAnchor,
                constant: -2
            ),
            scoreContainer.widthAnchor.constraint(
                greaterThanOrEqualToConstant: 40
            ),
            scoreContainer.heightAnchor.constraint(equalToConstant: 20),

            scoreLabel.centerXAnchor.constraint(
                equalTo: scoreContainer.centerXAnchor
            ),
            scoreLabel.centerYAnchor.constraint(
                equalTo: scoreContainer.centerYAnchor
            ),
            scoreLabel.leadingAnchor.constraint(
                equalTo: scoreContainer.leadingAnchor,
                constant: 6
            ),
            scoreLabel.trailingAnchor.constraint(
                equalTo: scoreContainer.trailingAnchor,
                constant: -6
            ),

            textLabel.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: 8
            ),
            textLabel.leadingAnchor.constraint(
                equalTo: scoreContainer.trailingAnchor,
                constant: 8
            ),
            textLabel.trailingAnchor.constraint(
                equalTo: container.trailingAnchor,
                constant: -8
            ),
            textLabel.bottomAnchor.constraint(
                equalTo: container.bottomAnchor,
                constant: -8
            ),
        ])

        return container
    }

    @objc private func headerTapped() {
        toggleExpanded()
    }

    func toggleExpanded() {
        isExpanded.toggle()
        updateExpandedState(animated: true)
    }

    private func updateExpandedState(animated: Bool) {
        let imageName = isExpanded ? "chevron.down" : "chevron.right"
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        let image = UIImage(systemName: imageName, withConfiguration: config)

        if animated {
            UIView.animate(withDuration: 0.25) {
                self.chevronImageView.image = image
            }
        } else {
            chevronImageView.image = image
        }

        guard let sourcesContainer = containerStack.arrangedSubviews.last else {
            return
        }

        sourcesContainer.isHidden = !isExpanded

        if isExpanded {
            sourcesContainerHeightConstraint?.isActive = false

            let totalHeight = sourcesStackView.arrangedSubviews.reduce(0) {
                total,
                view in
                let height = view.systemLayoutSizeFitting(
                    CGSize(
                        width: sourcesStackView.bounds.width,
                        height: UIView.layoutFittingCompressedSize.height
                    ),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                ).height
                return total + height + 6  // spacing
            }

            sourcesContainerHeightConstraint = sourcesContainer.heightAnchor
                .constraint(equalToConstant: totalHeight)
            sourcesContainerHeightConstraint?.isActive = true

            if animated {
                UIView.animate(withDuration: 0.25) {
                    self.layoutIfNeeded()
                }
            }
        } else {
            sourcesContainerHeightConstraint?.isActive = false
            sourcesContainerHeightConstraint = sourcesContainer.heightAnchor
                .constraint(equalToConstant: 0)
            sourcesContainerHeightConstraint?.isActive = true

            if animated {
                UIView.animate(withDuration: 0.25) {
                    self.layoutIfNeeded()
                } completion: { _ in
                    sourcesContainer.isHidden = true
                }
            }
        }
    }

    func setSources(_ sources: [RAGSource]) {
        self.sources = sources
        rebuildSourcesStack()
        titleLabel.text = L("chat.sources.title", sources.count)

        if isExpanded {
            updateExpandedState(animated: false)
        }
    }

    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        updateExpandedState(animated: animated)
    }
}

final class UIMessageSystemPromptView: UIView {
    
    // MARK: - Properties
    private var prompt: String = ""
    private var isExpanded: Bool = false
    private var colors = ThemeColors.dark
    
    // MARK: - UI Components
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
     
    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var headerButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = nil
        
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        let chevronImage = UIImage(systemName: "chevron.right", withConfiguration: config)
        
        var configBuilder = UIButton.Configuration.plain()
        configBuilder.image = UIImage(systemName: "doc.text")
        configBuilder.imagePlacement = .leading
        configBuilder.imagePadding = 4
        configBuilder.title = L("chat.systemPrompt.title")
        configBuilder.baseForegroundColor = .label
        
        button.configuration = configBuilder
        button.addTarget(self, action: #selector(headerTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        imageView.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        imageView.tintColor = .label
        return imageView
    }()
    
    private let promptLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 0
        return label
    }()
    
    private let promptContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()
    
    private var promptHeightConstraint: NSLayoutConstraint?
    
    // MARK: - Initialization
    
    func configure(prompt: String, colors: ThemeColors = .dark) {
        self.prompt = prompt
        self.colors = colors
        updateAppearance()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(containerStack)
        // Header button
        let headerStack = UIStackView(arrangedSubviews: [
            createIconImageView(named: "doc.text"),
            createTitleLabel(),
            chevronImageView
        ])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Prompt container with label
        promptContainer.addSubview(promptLabel)
        
        NSLayoutConstraint.activate([
            promptLabel.topAnchor.constraint(equalTo: promptContainer.topAnchor, constant: 8),
            promptLabel.leadingAnchor.constraint(equalTo: promptContainer.leadingAnchor, constant: 8),
            promptLabel.trailingAnchor.constraint(equalTo: promptContainer.trailingAnchor, constant: -8),
            promptLabel.bottomAnchor.constraint(equalTo: promptContainer.bottomAnchor, constant: -8),
            
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
        
        containerStack.addArrangedSubview(headerStack)
        containerStack.addArrangedSubview(promptContainer)
        
        // Initially collapsed
        promptContainer.isHidden = true
        promptHeightConstraint = promptContainer.heightAnchor.constraint(equalToConstant: 0)
        promptHeightConstraint?.isActive = true
        
        // Add tap gesture to header
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(headerTapped))
        headerStack.isUserInteractionEnabled = true
        headerStack.addGestureRecognizer(tapGesture)
        
        // Setup border and background
        setupBorderAndBackground()
    }
    
    private func createIconImageView(named systemName: String) -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        imageView.image = UIImage(systemName: systemName, withConfiguration: config)
        imageView.tintColor = UIColor(colors.accentColor)
        return imageView
    }
    
    private func createTitleLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("chat.systemPrompt.title")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(colors.primaryText)
        return label
    }
    
    private func setupBorderAndBackground() {
        promptContainer.backgroundColor = UIColor(colors.accentColor).withAlphaComponent(0.1)
        layer.cornerRadius = 8
        clipsToBounds = true
        
        // Add border
        let borderLayer = CAShapeLayer()
        borderLayer.strokeColor = UIColor(colors.accentColor).withAlphaComponent(0.3).cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 1
        borderLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: 8).cgPath
        borderLayer.frame = bounds
        layer.addSublayer(borderLayer)
    }
    
    private func updateAppearance() {
        promptLabel.text = prompt
        promptLabel.textColor = UIColor(colors.secondaryText)
    }
    
    // MARK: - Actions
    
    @objc private func headerTapped() {
        toggleExpanded()
    }
    
    func toggleExpanded() {
        isExpanded.toggle()
        
        let imageName = isExpanded ? "chevron.down" : "chevron.right"
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        let image = UIImage(systemName: imageName, withConfiguration: config)
        
        UIView.animate(withDuration: 0.25) {
            self.chevronImageView.image = image
        }
        
        promptContainer.isHidden = !isExpanded
        
        if isExpanded {
            promptHeightConstraint?.isActive = false
            promptContainer.layoutIfNeeded()
            
            let height = promptLabel.sizeThatFits(
                CGSize(width: promptContainer.bounds.width - 16, height: .greatestFiniteMagnitude)
            ).height + 16
            
            promptHeightConstraint = promptContainer.heightAnchor.constraint(equalToConstant: height)
            promptHeightConstraint?.isActive = true
            
            UIView.animate(withDuration: 0.25) {
                self.layoutIfNeeded()
            }
        } else {
            promptHeightConstraint?.isActive = false
            promptHeightConstraint = promptContainer.heightAnchor.constraint(equalToConstant: 0)
            promptHeightConstraint?.isActive = true
            
            UIView.animate(withDuration: 0.25) {
                self.layoutIfNeeded()
            } completion: { _ in
                self.promptContainer.isHidden = true
            }
        }
    }
    
    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard animated else {
            isExpanded = expanded
            promptContainer.isHidden = !expanded
            let imageName = expanded ? "chevron.down" : "chevron.right"
            chevronImageView.image = UIImage(systemName: imageName)
            return
        }
        
        if isExpanded != expanded {
            toggleExpanded()
        }
    }
}
