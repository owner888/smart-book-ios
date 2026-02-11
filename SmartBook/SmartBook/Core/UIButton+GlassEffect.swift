// UIButton+GlassEffect.swift - 液态玻璃按钮扩展

import UIKit

extension UIButton {

    /// 创建液态玻璃效果按钮
    /// - Parameters:
    ///   - title: 按钮文字
    ///   - icon: SF Symbol 图标名称
    ///   - target: 目标对象
    ///   - action: 点击事件
    /// - Returns: 配置好的按钮
    static func glassButton(
        title: String,
        icon: String,
        target: Any?,
        action: Selector
    ) -> UIButton {
        // ✅ iOS 26+ 使用系统玻璃效果，否则用 filled
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .filled()
        }

        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .clear
        // 标准大小
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(target, action: action, for: .touchUpInside)

        return button
    }

    /// 应用液态玻璃效果样式（iOS 25 及以下）
    /// - Parameter isDarkMode: 是否为深色模式
    func applyGlassEffect(isDarkMode: Bool) {
        // iOS 26+ 自动有玻璃效果，无需手动处理
        guard #unavailable(iOS 26.0) else { return }

        // 背景色
        if isDarkMode {
            backgroundColor = UIColor.apprBlack.withAlphaComponent(0.1)
        } else {
            backgroundColor = UIColor.apprWhite.withAlphaComponent(0.15)
        }

        layer.cornerRadius = 22
        layer.borderWidth = 0

        // ✅ 添加渐变边框层
        layer.sublayers?.filter { $0.name == "gradientBorder" }.forEach { $0.removeFromSuperlayer() }

        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "gradientBorder"
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = 22

        // 渐变颜色
        if isDarkMode {
            gradientLayer.colors = [
                UIColor.white.withAlphaComponent(0.25).cgColor,
                UIColor.white.withAlphaComponent(0.08).cgColor,
            ]
        } else {
            gradientLayer.colors = [
                UIColor.black.withAlphaComponent(0.15).cgColor,
                UIColor.black.withAlphaComponent(0.05).cgColor,
            ]
        }

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        // 创建遮罩，只显示边框
        let maskLayer = CAShapeLayer()
        let outerPath = UIBezierPath(roundedRect: gradientLayer.bounds, cornerRadius: 22)
        let innerPath = UIBezierPath(roundedRect: gradientLayer.bounds.insetBy(dx: 1, dy: 1), cornerRadius: 21)
        outerPath.append(innerPath.reversing())
        maskLayer.path = outerPath.cgPath
        maskLayer.fillRule = .evenOdd
        gradientLayer.mask = maskLayer

        layer.insertSublayer(gradientLayer, at: 0)

        // 阴影
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.shadowOpacity = isDarkMode ? 0.12 : 0.08
    }
}

// MARK: - 使用示例

/*

 // 方式 1: 使用工厂方法创建
 let button = UIButton.glassButton(
     title: "添加书籍",
     icon: "plus.circle.fill",
     target: self,
     action: #selector(addBookTapped)
 )

 // 方式 2: 手动配置 + 应用效果
 var config: UIButton.Configuration
 if #available(iOS 26.0, *) {
     config = .glass()
 } else {
     config = .filled()
 }

 config.title = "我的按钮"
 config.image = UIImage(systemName: "star.fill")
 config.baseForegroundColor = .white
 config.baseBackgroundColor = .clear
 config.cornerStyle = .capsule
 config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)

 let button = UIButton(configuration: config)

 // 应用玻璃效果
 let isDarkMode = traitCollection.userInterfaceStyle == .dark
 button.applyGlassEffect(isDarkMode: isDarkMode)

 // 在 layoutSubviews 中更新
 override func layoutSubviews() {
     super.layoutSubviews()
     button.applyGlassEffect(isDarkMode: traitCollection.userInterfaceStyle == .dark)
 }

 */
