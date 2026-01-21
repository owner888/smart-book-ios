// UIExtensions.swift - UI 扩展

import SwiftUI
import UIKit

// MARK: - View 扩展

extension View {
    /// 隐藏键盘
    func hiddenKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - CGRect 扩展

extension CGRect {
    /// 将 CGRect 转换为 EdgeInsets
    func edgeInset(_ size: CGSize) -> EdgeInsets {
        EdgeInsets(
            top: minY,
            leading: minX,
            bottom: size.height - maxY,
            trailing: size.width - maxX
        )
    }
}
