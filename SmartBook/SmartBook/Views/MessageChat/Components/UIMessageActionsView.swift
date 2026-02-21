//
//  UIMessageActionsView.swift
//  SmartBook
//
//  Extracted from MessageDisplayView.swift
//

import SwiftUI
import UIKit

// MARK: - 消息操作按钮视图（与 SwiftUI MessageActionsView 一致）
final class UIMessageActionsView: UIView {

    private var content: String = ""

    private let stackView: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 16
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private lazy var copyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 12)
        let image = UIImage(systemName: "doc.on.doc", withConfiguration: config)

        var btnConfig = UIButton.Configuration.plain()
        btnConfig.image = image
        btnConfig.title = L("chat.contextMenu.copy")
        btnConfig.imagePadding = 4
        btnConfig.contentInsets = .init(top: 4, leading: 0, bottom: 4, trailing: 0)
        btnConfig.baseForegroundColor = .secondaryLabel

        // 使用 caption 字体 (12pt)
        btnConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 12)
            return outgoing
        }

        btn.configuration = btnConfig
        btn.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        return btn
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        addSubview(stackView)
        stackView.addArrangedSubview(copyButton)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func configure(content: String, colors: ThemeColors) {
        self.content = content
        copyButton.configuration?.baseForegroundColor = UIColor(colors.secondaryText)
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = content

        // ✅ 复制成功反馈：临时变为 "已复制" + checkmark
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        let checkImage = UIImage(systemName: "checkmark", withConfiguration: config)
        copyButton.configuration?.image = checkImage
        copyButton.configuration?.title = L("message.action.copied")
        copyButton.configuration?.baseForegroundColor = .systemGreen

        // 1.5 秒后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            let docImage = UIImage(systemName: "doc.on.doc", withConfiguration: config)
            self.copyButton.configuration?.image = docImage
            self.copyButton.configuration?.title = L("chat.contextMenu.copy")
            self.copyButton.configuration?.baseForegroundColor = .secondaryLabel
        }
    }
}
