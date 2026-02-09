// Components.swift - UI 组件

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

// MARK: - 主要操作按钮样式（用于空状态等场景）
struct PrimaryActionButtonStyle: ButtonStyle {
    var colors: ThemeColors = .dark
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    // 液态玻璃效果 - 多层叠加
                    Color.black.opacity(0.15)
                        .background(.ultraThinMaterial)
                    Color.white.opacity(configuration.isPressed ? 0.08 : 0.05)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(configuration.isPressed ? 0.2 : 0.25),
                                Color.white.opacity(configuration.isPressed ? 0.05 : 0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.12),
                radius: configuration.isPressed ? 8 : 12,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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

extension ButtonStyle where Self == PrimaryActionButtonStyle {
    static func primaryAction(colors: ThemeColors = .dark) -> PrimaryActionButtonStyle {
        PrimaryActionButtonStyle(colors: colors)
    }
}

// MARK: - 玻璃效果视图扩展
extension View {
    /// 条件修饰器扩展
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
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
    
    // Menu专用玻璃效果（圆形，不干扰交互）
    func menuGlassEffect() -> some View {
        self
            .padding(14)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                Circle()
                    .stroke(
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

// MARK: - 书籍封面组件
struct BookCoverView: View {
    let book: Book
    var colors: ThemeColors = .dark
    var showTitle: Bool = false
    
    var body: some View {
        ZStack {
            coverImage
        }
    }
    
    @ViewBuilder
    private var coverImage: some View {
        if let coverURLString = book.coverURL,
           let coverURL = URL(string: coverURLString) {
            if coverURL.isFileURL {
                if let uiImage = UIImage(contentsOfFile: coverURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderCover
                }
            } else {
                AsyncImage(url: coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderCover
                }
            }
        } else {
            placeholderCover
        }
    }
    
    private var placeholderCover: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [colors.inputBackground, colors.inputBackground.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.largeTitle) // 大标题 - 动态字号
                        .foregroundColor(colors.secondaryText.opacity(0.5))
                    if showTitle {
                        Text(book.title)
                            .font(.caption2)
                            .foregroundColor(colors.secondaryText.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 8)
                    }
                }
            }
    }
}
