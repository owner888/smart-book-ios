// Components.swift - 通用 UI 组件

import SwiftUI

// MARK: - iOS 26 液态玻璃效果按钮样式
struct GlassButtonStyle: ButtonStyle {
    var foregroundColor: Color = .primary
    var shadowColor: Color = .black.opacity(0.15)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(
                                    configuration.isPressed ? 0.12 : 0.18
                                ),
                                .white.opacity(
                                    configuration.isPressed ? 0.02 : 0.05
                                ),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(
                color: shadowColor,
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 液态玻璃图标按钮样式
struct GlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    var color: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(
                                    configuration.isPressed ? 0.15 : 0.25
                                ),
                                .white.opacity(
                                    configuration.isPressed ? 0.03 : 0.08
                                ),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.1 : 0.2),
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .foregroundColor(color)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 按钮样式扩展
extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle {
        GlassButtonStyle()
    }
}

extension ButtonStyle where Self == GlassIconButtonStyle {
    static var glassIcon: GlassIconButtonStyle {
        GlassIconButtonStyle()
    }
}

// MARK: - 玻璃效果视图扩展
extension View {
    func glassEffect() -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                .white.opacity(0.05),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
