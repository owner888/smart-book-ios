//
//  UIMessageThinkingView.swift
//  SmartBook
//
//  Extracted from MessageDisplayView.swift
//

import SwiftUI
import UIKit

final class UIMessageThinkingView: UIView {

    // ✅ 纯代码实现，支持展开/收缩（与 SwiftUI MessageThinkingView 一致）
    // 使用 UIStackView 包裹 header + content，isHidden 自动折叠布局

    private var isExpanded = false

    // === 外层 StackView（自动折叠 isHidden 的子视图）===
    private let outerStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 0
        s.alignment = .fill
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // === Header 区域（始终显示）===
    private let headerStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .center
        s.spacing = 6
        s.translatesAutoresizingMaskIntoConstraints = false
        s.isLayoutMarginsRelativeArrangement = true
        s.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return s
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "brain.head.profile"))
        iv.tintColor = .systemPurple
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Thinking..."
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let chevronView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        let iv = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: config))
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // === 展开内容区域（放在 outerStack 中，isHidden 时自动折叠）===
    private let contentWrapper: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true  // 默认收缩
        return v
    }()

    private let contentBg: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 8
        v.clipsToBounds = true
        return v
    }()

    private let contentLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    var thinking: String = "" {
        didSet {
            // ✅ 去掉首尾多余换行（Gemini thinking 文本末尾通常带 \n\n）
            contentLabel.text = thinking.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var colors: ThemeColors = .dark {
        didSet {
            updateColors()
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
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemPurple.withAlphaComponent(0.3).cgColor
        backgroundColor = UIColor.systemPurple.withAlphaComponent(0.05)

        // Header: icon + "Thinking..." + Spacer + chevron
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(spacer)
        headerStack.addArrangedSubview(chevronView)

        // Content: wrapper > bg > label
        contentBg.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        contentBg.addSubview(contentLabel)
        contentWrapper.addSubview(contentBg)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            contentBg.topAnchor.constraint(equalTo: contentWrapper.topAnchor),
            contentBg.leadingAnchor.constraint(equalTo: contentWrapper.leadingAnchor, constant: 8),
            contentBg.trailingAnchor.constraint(equalTo: contentWrapper.trailingAnchor, constant: -8),
            contentBg.bottomAnchor.constraint(equalTo: contentWrapper.bottomAnchor, constant: -8),

            contentLabel.topAnchor.constraint(equalTo: contentBg.topAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: contentBg.leadingAnchor, constant: 8),
            contentLabel.trailingAnchor.constraint(equalTo: contentBg.trailingAnchor, constant: -8),
            contentLabel.bottomAnchor.constraint(equalTo: contentBg.bottomAnchor, constant: -8),
        ])

        // 外层 StackView：header + contentWrapper
        // ✅ UIStackView 中 isHidden=true 的子视图会自动折叠（不占空间）
        outerStack.addArrangedSubview(headerStack)
        outerStack.addArrangedSubview(contentWrapper)
        addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // 点击 header 切换展开/收缩
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleExpanded))
        headerStack.isUserInteractionEnabled = true
        headerStack.addGestureRecognizer(tap)

        updateColors()
    }

    private func updateColors() {
        titleLabel.textColor = UIColor(colors.primaryText)
        chevronView.tintColor = UIColor(colors.primaryText)
        contentLabel.textColor = UIColor(colors.secondaryText)
    }

    @objc private func toggleExpanded() {
        isExpanded.toggle()

        let chevronName = isExpanded ? "chevron.down" : "chevron.right"
        let config = UIImage.SymbolConfiguration(pointSize: 12)
        chevronView.image = UIImage(systemName: chevronName, withConfiguration: config)

        UIView.animate(withDuration: 0.2) {
            self.contentWrapper.isHidden = !self.isExpanded
            self.layoutIfNeeded()
        } completion: { _ in
            // ✅ 通知 tableView 重新计算 cell 高度
            if let tableView = self.findTableView() {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

    /// 向上查找最近的 UITableView
    private func findTableView() -> UITableView? {
        var view: UIView? = superview
        while let v = view {
            if let tv = v as? UITableView { return tv }
            view = v.superview
        }
        return nil
    }
}
