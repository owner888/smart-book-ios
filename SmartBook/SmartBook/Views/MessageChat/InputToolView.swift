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
    @IBOutlet weak private var mediaView: UICollectionView!

    private var isRecording = false
    private var isConnecting = false
    private var isEditing = false
    private var mediaItems = [MediaItem]()

    // ✅ 语音识别服务（UIKit 方式）
    private lazy var speechService = SpeechService()
    private lazy var asrStreamService = ASRStreamService()
    private var asrProvider: String {
        UserDefaults.standard.string(forKey: AppConfig.Keys.asrProvider)
            ?? AppConfig.DefaultValues.asrProvider
    }

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
        layer.masksToBounds = false  // ✅ 改为 false，让媒体预览可见
        layer.cornerRadius = 22
        // ✅ 使用液态玻璃边框代替普通边框
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)

        // ✅ 调整 textView 内边距，让文字往右下移
        textView.textContainerInset = UIEdgeInsets(
            top: 12,
            left: 8,
            bottom: 12,
            right: 8
        )

        // ✅ 调整占位符位置，往右下移动
        inputPromit.transform = CGAffineTransform(translationX: 8, y: 4)


        self.mediaView.register(
            MediaCollectionCell.self,
            forCellWithReuseIdentifier: MediaCollectionCell.identifier
        )
        
        // ✅ 启用 bounces，让 UICollectionView 在边界处也能响应拖拽
        // 这样当 contentOffset == 0 时，scrollViewWillBeginDragging 仍会被调用
        mediaView.bounces = true
        mediaView.alwaysBounceHorizontal = true
        
        // ✅ 添加手势识别器来检测横向拖拽
        // 当 UICollectionView 没有内容或已到边界时，scrollViewWillBeginDragging 可能不会被调用
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        mediaView.addGestureRecognizer(panGesture)

        sendBtn.configuration?.preferredSymbolConfigurationForImage =
            UIImage.SymbolConfiguration(pointSize: 15)
        configVoiceBtn()

        // ✅ 调整底部按钮往上移动
        let bottomOffset: CGFloat = -4  // 往上移 4pt
        mediaBtn.transform = CGAffineTransform(translationX: 0, y: bottomOffset)
        assistantBtn.transform = CGAffineTransform(
            translationX: 0,
            y: bottomOffset
        )
        //        modelButton.transform = CGAffineTransform(translationX: 0, y: 4)
        voiceBtn.superview?.transform = CGAffineTransform(
            translationX: 0,
            y: bottomOffset
        )

        voiceBtn.superview?.layer.masksToBounds = true
        voiceBtn.superview?.layer.cornerRadius = 15
        // ✅ 统一 mediaBtn 和 modelButton 的样式
        [mediaBtn, modelButton].forEach { btn in
            if #available(iOS 26, *) {
                btn?.configuration = .glass()
            } else {
                btn?.configuration?.background.visualEffect = UIBlurEffect(
                    style: .systemUltraThinMaterial
                )
            }
        }

        // 媒体按钮图标
        mediaBtn.configuration?.image = UIImage(systemName: "link")
        let imageConfig = UIImage.SymbolConfiguration(
            pointSize: 20,
            weight: .regular,
            scale: .small
        )
        mediaBtn.configuration?.preferredSymbolConfigurationForImage =
            imageConfig

        // 模型按钮（保持原有的容器圆角处理）
        let modelBgView = modelButton.superview
        modelBgView?.layer.masksToBounds = true
        modelBgView?.layer.cornerRadius = 12

        // ✅ 直接用代码添加点击事件，不依赖 XIB 连接
        voiceBtn?.addTarget(
            self,
            action: #selector(toggleVoiceRecording(_:)),
            for: .touchUpInside
        )

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MainChangePage"),
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self else { return }
            if (notification.object as? Bool) == true {
                if self.isEditing {
                    self.textView.becomeFirstResponder()
                }
            } else {
                self.isEditing = self.textView.isFirstResponder
                self.textView.resignFirstResponder()
            }
        }
    }

    func bind(to model: ChatViewModel) {
        self.viewModel = model
        model.$inputText.receive(on: DispatchQueue.main).sink {
            [weak self] text in
            guard let self = self else { return }
            if text.isEmpty {
                textView.text = ""
                updateUI()
            }
        }.store(in: &cancellables)

        // ✅ 监听 mediaItems 变化
        model.$mediaItems.receive(on: DispatchQueue.main).sink {
            [weak self] items in
            guard let self = self else { return }
            self.mediaItems = items
            self.mediaView.isHidden = items.isEmpty
            self.mediaView.reloadData()
            self.layoutIfNeeded()
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
        let imageConfig = UIImage.SymbolConfiguration(
            pointSize: 15,
            weight: .regular,
            scale: .small
        )
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePadding = 8
        config.title = title
        config.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                return outgoing
            }
        voiceBtn.configuration = config
    }

    func updateUI() {
        let isEmpty = textView.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
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

    // MARK: - Speaking Button Action

    @IBAction func toggleVoiceRecording(_ sender: UIButton) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Voice Recognition

    private func startRecording() {
        // 根据配置选择语音识别服务
        switch asrProvider {
        case "native":
            isRecording = true
            configVoiceBtn()

            // 使用 iOS 原生语音识别
            Task { @MainActor in
                speechService.startRecording(
                    onInterim: { [weak self] text in
                        self?.textView.text = text
                        self?.viewModel?.inputText = text
                        self?.updateUI()
                    },
                    onFinal: { [weak self] text in
                        self?.textView.text = text
                        self?.viewModel?.inputText = text
                        self?.isRecording = false
                        self?.configVoiceBtn()
                        self?.updateUI()
                    }
                )
            }
            Logger.info("🎤 使用 iOS 原生语音识别")

        default:
            // 使用 Deepgram 流式识别
            Task {
                // 显示连接中状态
                await MainActor.run {
                    isConnecting = true
                    configVoiceBtn()
                }

                // 如果未连接，先连接
                if !asrStreamService.isConnected {
                    await asrStreamService.connect()
                }

                // 开始录音和流式识别
                await asrStreamService.startRecording(
                    onDeepgramReady: { [weak self] in
                        Task { @MainActor in
                            self?.isConnecting = false
                            self?.isRecording = true
                            self?.configVoiceBtn()
                            Logger.info("✅ Deepgram 就绪，开始录音")
                        }
                    },
                    onTranscriptUpdate: { [weak self] text, isFinal in
                        Task { @MainActor in
                            self?.textView.text = text
                            self?.viewModel?.inputText = text
                            self?.updateUI()

                            // 最终结果时自动停止并发送
                            if isFinal {
                                self?.isRecording = false
                                await self?.asrStreamService.stopRecording()

                                // 严格检查：文本必须有实际内容才自动发送
                                let trimmedText = text.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                if trimmedText.count >= 2 {
                                    Logger.info("✅ 语音识别完成，自动发送: \(trimmedText)")

                                    // 延迟一点，确保清理完成
                                    try? await Task.sleep(
                                        nanoseconds: 100_000_000
                                    )

                                    // 语音模式发送，启用 TTS
                                    await self?.viewModel?.sendMessage(
                                        trimmedText,
                                        enableTTS: true
                                    )

                                    // 清空输入框
                                    await MainActor.run {
                                        self?.textView.text = ""
                                        self?.viewModel?.inputText = ""
                                        self?.configVoiceBtn()
                                        self?.updateUI()
                                    }
                                } else {
                                    Logger.warning(
                                        "⚠️ 识别文本太短或为空，不自动发送: '\(trimmedText)'"
                                    )
                                    await MainActor.run {
                                        self?.configVoiceBtn()
                                    }
                                }
                            }
                        }
                    }
                )
            }
            Logger.info("🎙️ 使用 Deepgram 流式识别（等待就绪 + 实时断句 + 自动发送）")
        }
    }

    private func stopRecording() {
        isRecording = false
        configVoiceBtn()

        // 停止对应的语音识别服务
        switch asrProvider {
        case "native":
            Task { @MainActor in
                speechService.stopRecording()
            }
        default:
            Task {
                // 只停止录音，保持 WebSocket 连接
                await asrStreamService.stopRecording()
            }
        }

        Logger.info("🛑 停止录音（连接保持）")
    }

    // MARK: - Lifecycle

    override func layoutSubviews() {
        super.layoutSubviews()
        // ✅ 更新玻璃边框
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(
            comparedTo: previousTraitCollection
        ) {
            // ✅ 主题变化时更新边框
            let isDarkMode = traitCollection.userInterfaceStyle == .dark
            applyGlassBorder(cornerRadius: 22, isDarkMode: isDarkMode)
        }
    }
}

extension InputToolView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let size = textView.sizeThatFits(
            CGSize(width: textView.frame.width, height: .infinity)
        )
        inputHeight.constant = max(min(size.height, 180), 60)
        viewModel?.inputText = textView.text
        updateUI()
    }
}

extension InputToolView: UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return mediaItems.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MediaCollectionCell.identifier,
            for: indexPath
        ) as? MediaCollectionCell {
            cell.mediaItem = mediaItems[indexPath.item]
            cell.index = indexPath.item
            cell.delete = { [weak self] index in
                guard let self = self,
                    let viewModel = self.viewModel,
                    index < viewModel.mediaItems.count
                else { return }
                viewModel.mediaItems.remove(at: index)
            }
            return cell
        }
        return UICollectionViewCell()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        NotificationCenter.default.post(name: .disableExpandScroll, object: true)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView,
                                  willDecelerate decelerate: Bool) {
      //  reScroll()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        reScroll()
    }
    
    // MARK: - Pan Gesture Handler
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        
        switch gesture.state {
        case .began:
            NotificationCenter.default.post(
                name: .disableExpandScroll,
                object: true
            )
        case .ended, .cancelled:
            reScroll()
        default:
            break
        }
    }
    
    private func reScroll() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: {
            NotificationCenter.default.post(name: .disableExpandScroll, object: false)
        })
    }
}

// MARK: - UIGestureRecognizerDelegate
extension InputToolView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // ✅ 允许手势同时识别，这样 UICollectionView 的滚动和手势识别器可以同时工作
        return true
    }
}

class MediaCollectionCell: UICollectionViewCell {
    static let identifier = "MedialCell"
    var mediaItem: MediaItem? {
        didSet {
            if let item = mediaItem {
                switch item.type {
                case .image(let uiImage):
                    mediaView.image = uiImage
                case .document(let url):
                    mediaView.image = UIImage(systemName: "doc.fill")
                    mediaView.tintColor = .gray
                }
            }
        }
    }
    
    lazy var mediaView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    var index: Int?
    var delete: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    

    func setUp() {

        //        switch item.type {
        //        case .image(let uiImage):
        //            imageView.image = uiImage
        //        case .document(let url):
        //            imageView.image = UIImage(systemName: "doc.fill")
        //            imageView.tintColor = .gray
        //        }
        self.addSubview(mediaView)

        // 删除按钮
        let deleteBtn = UIButton(type: .custom)
        deleteBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        deleteBtn.tintColor = .white  // ✅ 白色X
        deleteBtn.backgroundColor = .black.withAlphaComponent(0.8)  // ✅ 黑色背景
        deleteBtn.layer.cornerRadius = 14
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        deleteBtn.addTarget(
            self,
            action: #selector(deleteMediaItem(_:)),
            for: .touchUpInside
        )
        self.addSubview(deleteBtn)

        NSLayoutConstraint.activate([
            mediaView.topAnchor.constraint(equalTo: topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mediaView.bottomAnchor.constraint(equalTo: bottomAnchor),

            deleteBtn.widthAnchor.constraint(equalToConstant: 28),
            deleteBtn.heightAnchor.constraint(equalToConstant: 28),
            deleteBtn.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            deleteBtn.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -4
            ),
        ])
    }

    @objc private func deleteMediaItem(_ sender: UIButton) {
        if let index = index {
            delete?(index)
        }

        //        let index = sender.tag

    }
}
