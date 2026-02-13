//
//  MessageContentView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/9.
//

import SwiftUI
import UIKit

class MessageDisplayView: UIView {
    
    var message: ChatMessage?
    var assistant: Assistant?  // 可选，简单模式时为nil
    var colors: ThemeColors = .dark
    var onChangedSized:((ChatMessage?,CGFloat) -> Void)?
    
    
    @IBOutlet weak private var headerView: UIMessageAssistantHeaderView?
    @IBOutlet weak private var promptView: UIMessageSystemPromptView?
    @IBOutlet weak private var thinkingView: UIMessageThinkingView?
    @IBOutlet weak private var userTextHeight: NSLayoutConstraint?
    @IBOutlet weak private var userTextViewWidth: NSLayoutConstraint?
    @IBOutlet weak private var userMessageView: UIView?
    @IBOutlet weak private var userTextView: CustomTextView?
    @IBOutlet weak private var textViewHeight: NSLayoutConstraint?
    @IBOutlet weak private var textView:CustomTextView?
    @IBOutlet weak private var messageView: UIView?
    @IBOutlet weak private var stackView: UIStackView?
    @IBOutlet weak private var mainStackView: UIStackView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
        setUp()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
        setUp()
    }
    
    func loadXib() {
        let nib = UINib(nibName: "MessageDisplayView", bundle: nil)
        if let view = nib.instantiate(withOwner:self).first as? UIView {
            view.frame = self.bounds
            view.autoresizingMask = [.flexibleWidth,.flexibleHeight]
            self.addSubview(view)
        }
    }
    
    func setUp() {
        configureTextView(textView)
        configureTextView(userTextView)
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
    
    private func displayMessageContent(_ message: ChatMessage) {
        if message.role == .user {
            guard let textView = userTextView else {
                return
            }
            stackView?.alignment = .trailing
            mainStackView?.alignment = .trailing
            messageView?.isHidden = true
            userMessageView?.isHidden  = false
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
            onChangedSized?(message,newSize.height + 24)
        } else {
            guard let textView = textView else {
                return
            }
            stackView?.alignment = .leading
            mainStackView?.alignment = .leading
            userMessageView?.isHidden = true
            messageView?.isHidden = false
            
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
    @IBOutlet weak private var label: UILabel?

    var thinking: String = "" {
        didSet {
            label?.text = thinking
        }
    }


    // MARK: - UI Components
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
        setUp()
    }

    func loadXib() {
        let nib = UINib(nibName: "UIMessageThinkingView", bundle: nil)
        if let view = nib.instantiate(withOwner: self).first as? UIView {
            view.frame = self.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.addSubview(view)
        }
    }
    
    func setUp() {
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 6
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.systemPurple.withAlphaComponent(0.8).cgColor
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
