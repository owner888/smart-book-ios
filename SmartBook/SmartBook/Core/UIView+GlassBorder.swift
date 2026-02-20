// UIView+GlassBorder.swift - UIView 液态玻璃边框扩展

import UIKit

extension UIView {

    /// 应用液态玻璃渐变边框
    /// - Parameters:
    ///   - cornerRadius: 圆角半径
    ///   - isDarkMode: 是否为深色模式
    func applyGlassBorder(cornerRadius: CGFloat = 12, isDarkMode: Bool) {
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
        layer.borderWidth = 0  // 不使用普通边框

        // 移除旧的渐变边框层
        layer.sublayers?.filter { $0.name == "glassBorder" }.forEach { $0.removeFromSuperlayer() }

        // 创建渐变边框层
        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "glassBorder"
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = cornerRadius

        // 渐变颜色
        if isDarkMode {
            gradientLayer.colors = [
                UIColor.white.withAlphaComponent(0.25).cgColor,  // 左上亮
                UIColor.white.withAlphaComponent(0.08).cgColor,  // 右下暗
            ]
        } else {
            gradientLayer.colors = [
                UIColor.black.withAlphaComponent(0.15).cgColor,  // 左上
                UIColor.black.withAlphaComponent(0.05).cgColor,  // 右下
            ]
        }

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        // 创建遮罩，只显示边框
        let maskLayer = CAShapeLayer()
        let borderWidth: CGFloat = 2  // 边框宽度
        let outerPath = UIBezierPath(roundedRect: gradientLayer.bounds, cornerRadius: cornerRadius)
        let innerPath = UIBezierPath(
            roundedRect: gradientLayer.bounds.insetBy(dx: borderWidth, dy: borderWidth),
            cornerRadius: cornerRadius - borderWidth
        )
        outerPath.append(innerPath.reversing())
        maskLayer.path = outerPath.cgPath
        maskLayer.fillRule = .evenOdd
        gradientLayer.mask = maskLayer

        layer.insertSublayer(gradientLayer, at: 0)
    }

    /// 移除液态玻璃边框
    func removeGlassBorder() {
        layer.sublayers?.filter { $0.name == "glassBorder" }.forEach { $0.removeFromSuperlayer() }
    }
}
