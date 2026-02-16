//
//  UIMessageToolsView.swift
//  SmartBook
//
//  Extracted from MessageDisplayView.swift
//

import SwiftUI
import UIKit

// MARK: - 工具使用胶囊视图（与 SwiftUI MessageToolsView 一致）
final class UIMessageToolsView: UIView {
    
    /// 水平流式布局：多个胶囊自动换行
    private let flowStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 6
        s.alignment = .center
        s.distribution = .fill
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
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
        addSubview(flowStack)
        NSLayoutConstraint.activate([
            flowStack.topAnchor.constraint(equalTo: topAnchor),
            flowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            flowStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            flowStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    func configure(tools: [ToolInfo], colors: ThemeColors) {
        // 清除旧的胶囊
        flowStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for tool in tools {
            let capsule = createCapsule(tool: tool, colors: colors)
            flowStack.addArrangedSubview(capsule)
        }
    }
    
    /// 创建单个工具胶囊（与 SwiftUI Capsule 样式一致）
    private func createCapsule(tool: ToolInfo, colors: ThemeColors) -> UIView {
        let label = UILabel()
        label.text = tool.name
        label.font = .systemFont(ofSize: 11, weight: .medium)  // caption2 + medium
        label.textColor = tool.success
            ? UIColor(colors.secondaryText)
            : .systemRed
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        // 胶囊样式：蓝色/红色背景 + 边框
        let tintColor: UIColor = tool.success ? .systemBlue : .systemRed
        container.backgroundColor = tintColor.withAlphaComponent(0.1)
        container.layer.cornerRadius = 12  // 胶囊圆角
        container.layer.borderWidth = 0.5
        container.layer.borderColor = tintColor.withAlphaComponent(0.3).cgColor
        container.clipsToBounds = true
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])
        
        return container
    }
}
