// SettingsComponents.swift - 设置页面通用组件

import SwiftUI

// MARK: - 设置项图标
struct SettingsIcon: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.subheadline)  // 15号 - 动态字号
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - 设置项行
struct SettingsRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    var colors: ThemeColors = .dark
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(icon: icon, color: iconColor)
            Text(title)
                .foregroundColor(colors.primaryText)
            Spacer()
            content()
        }
    }
}
