//
//  InputToolView.swift
//  SmartBook
//
//  Created by Andrew on 2026/2/7.
//

import Combine
import UIKit

class InputToolView: UIView {
    @IBOutlet weak private var textView: UITextView!
    @IBOutlet weak private var inputHeight: NSLayoutConstraint!
    @IBOutlet weak private var inputPromit: UILabel!
    @IBOutlet weak private var sendBtn: UIButton!
    @IBOutlet weak private var voiceBtn: UIButton!
    @IBOutlet weak private var mediaBtn: UIButton!
    @IBOutlet weak private var blurView: UIBlurView!
    @IBOutlet weak private var modelButton: UIButton!
    @IBOutlet weak private var assistantBtn: UIButton!
    @IBOutlet weak private var chatBtnIcon: MenuIconView!
    @IBOutlet weak private var chatBtnTitle: UILabel!

    private var isRecording = false
    private var isConnecting = false

    var viewModel: ChatViewModel?
    var aiFunction = MenuConfig.AIModelFunctionType.auto {
        didSet {
            chatBtnIcon.configure(aiFunction.config, size: 14)
            chatBtnTitle.text = aiFunction.config.title
        }
    }
    var assistant = MenuConfig.AssistantType.chat {
        didSet {
            assistantBtn.setTitle(assistant.config.icon, for: .normal)
        }
    }
    var send: (() -> Void)?
    var showPopover: ((MessagePopoverAction, UIView) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    
    // ✅ 媒体预览容器
    private lazy var mediaPreviewContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .fill  // ✅ 改为 fill，避免约束冲突
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true  // 默认隐藏
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
    }

    func loadXib() {
        let nib = UINib(nibName: "InputToolView", bundle: nil)
        if let view = nib.instantiate(withOwner: self).first as? UIView {
            view.frame = self.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(view)
        }
        setUp()
    }

    func setUp() {
        layer.masksToBounds = false  // ✅ 改为 false，让媒体预览可见
        layer.cornerRadius = 22
        // ✅ 使用液态玻璃边框代替普通边框
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)

        // ✅ 调整 textView 内边距，让文字往右下移
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)

        // ✅ 调整占位符位置，往右下移动
        inputPromit.transform = CGAffineTransform(translationX: 8, y: 4)
        
        // ✅ 添加媒体预览容器到 textView 内部顶部
        textView.addSubview(mediaPreviewContainer)
        NSLayoutConstraint.activate([
            mediaPreviewContainer.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 8),
            mediaPreviewContainer.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -8),
            mediaPreviewContainer.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),
            mediaPreviewContainer.heightAnchor.constraint(equalToConstant: 60)
        ])

        sendBtn.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15)
        configVoiceBtn()

        // ✅ 调整底部按钮往上移动
        let bottomOffset: CGFloat = -4  // 往上移 4pt
        mediaBtn.transform = CGAffineTransform(translationX: 0, y: bottomOffset)
        assistantBtn.transform = CGAffineTransform(translationX: 0, y: bottomOffset)
        modelButton.transform = CGAffineTransform(translationX: 0, y: bottomOffset)
        voiceBtn.superview?.transform = CGAffineTransform(translationX: 0, y: bottomOffset)

        voiceBtn.superview?.layer.masksToBounds = true
        voiceBtn.superview?.layer.cornerRadius = 15
        // ✅ 统一 mediaBtn 和 modelButton 的样式
        [mediaBtn, modelButton].forEach { btn in
            if #available(iOS 26, *) {
                btn?.configuration = .glass()
            } else {
                btn?.configuration?.background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            }
        }

        // 媒体按钮图标
        mediaBtn.configuration?.image = UIImage(systemName: "link")
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular, scale: .small)
        mediaBtn.configuration?.preferredSymbolConfigurationForImage = imageConfig

        // 模型按钮（保持原有的容器圆角处理）
        let modelBgView = modelButton.superview
        modelBgView?.layer.masksToBounds = true
        modelBgView?.layer.cornerRadius = 12
    }

    func bind(to model: ChatViewModel) {
        self.viewModel = model
        model.$inputText.receive(on: DispatchQueue.main).sink { [weak self] text in
            guard let self = self else { return }
            if text.isEmpty {
                textView.text = ""
                updateUI()
            }
        }.store(in: &cancellables)
        
        // ✅ 监听 mediaItems 变化
        model.$mediaItems.receive(on: DispatchQueue.main).sink { [weak self] items in
            guard let self = self else { return }
            self.displayMediaItems(items)
        }.store(in: &cancellables)
    }
    
    // ✅ 显示媒体预览
    private func displayMediaItems(_ items: [MediaItem]) {
        // 清空旧的预览
        mediaPreviewContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if items.isEmpty {
            mediaPreviewContainer.isHidden = true
            mediaPreviewContainer.backgroundColor = .clear
            return
        }
        
        // ✅ 调试：添加背景色看是否显示
        mediaPreviewContainer.backgroundColor = .red.withAlphaComponent(0.3)
        
        // 显示媒体预览
        for (index, item) in items.enumerated() {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            imageView.backgroundColor = .blue  // 调试背景
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            switch item.type {
            case .image(let uiImage):
                imageView.image = uiImage
                print("🖼️ 设置图片：\(uiImage.size)")
            case .document(let url):
                imageView.image = UIImage(systemName: "doc.fill")
                imageView.tintColor = .gray
            }
            
            // ✅ 降低优先级，避免约束冲突
            let widthConstraint = imageView.widthAnchor.constraint(equalToConstant: 60)
            widthConstraint.priority = .defaultHigh
            NSLayoutConstraint.activate([
                widthConstraint,
                imageView.heightAnchor.constraint(equalToConstant: 60)
            ])
            
            mediaPreviewContainer.addArrangedSubview(imageView)
        }
        
        mediaPreviewContainer.isHidden = false
        print("📷 显示 \(items.count) 个媒体预览")
        print("📐 容器 frame: \(mediaPreviewContainer.frame)")
        print("📐 容器 isHidden: \(mediaPreviewContainer.isHidden)")
    }

    func configVoiceBtn() {
        var icon = "waveform"
        var title = L("chat.voice.start")
        if isConnecting {
            icon = "arrow.triangle.2.circlepath"
            title = L("chat.voice.start")
        } else if isRecording {
            icon = "stop.fill"
            title = L("chat.voice.stop")
        }
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor.clear
        config.baseForegroundColor = UIColor.apprWhite
        config.image = UIImage(systemName: icon)
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular, scale: .small)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePadding = 8
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            return outgoing
        }
        voiceBtn.configuration = config
    }

    func updateUI() {
        let isEmpty = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        inputPromit.isHidden = !isEmpty
        voiceBtn.superview?.isHidden = !isEmpty
        sendBtn.isHidden = isEmpty

    }

    @IBAction func openMedia(_ sender: UIButton) {
        showPopover?(.openMedia, sender)
    }

    @IBAction func changeModel(_ sender: UIButton) {
        showPopover?(.chooseModel, sender)
    }

    @IBAction func changeAssistant(_ sender: UIButton) {
        showPopover?(.assistant, sender)
    }

    @IBAction func sendMessage() {
        send?()
    }

    // MARK: - Lifecycle

    override func layoutSubviews() {
        super.layoutSubviews()
        // ✅ 更新玻璃边框
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // ✅ 主题变化时更新边框
            let isDarkMode = traitCollection.userInterfaceStyle == .dark
            applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)
        }
    }
}

extension InputToolView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
        inputHeight.constant = max(min(size.height, 180), 60)
        viewModel?.inputText = textView.text
        updateUI()
    }
}
