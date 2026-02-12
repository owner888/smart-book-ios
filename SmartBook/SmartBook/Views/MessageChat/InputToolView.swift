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
        layer.masksToBounds = true
        layer.cornerRadius = 22  // ✅ 改为 22，和 Add Book 按钮一致
        // ✅ 使用液态玻璃边框代替普通边框
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)
        
        // ✅ 调整 textView 内边距，让文字往右下移
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        
        // ✅ 调整占位符位置，往右下移动
        inputPromit.transform = CGAffineTransform(translationX: 8, y: 4)
        
        sendBtn.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15)
        configVoiceBtn()

        voiceBtn.superview?.layer.masksToBounds = true
        voiceBtn.superview?.layer.cornerRadius = 15
        [mediaBtn].forEach { btn in
            if #available(iOS 26, *) {
                btn.configuration = .glass()
            } else {
                btn.configuration?.background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            }
        }

        mediaBtn.configuration?.image = UIImage(systemName: "link")
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular, scale: .small)
        mediaBtn.configuration?.preferredSymbolConfigurationForImage = imageConfig

        if #available(iOS 26, *) {
            modelButton.configuration = .glass()
        } else {
            modelButton.configuration?.background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
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
