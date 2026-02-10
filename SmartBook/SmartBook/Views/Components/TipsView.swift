// TipsView.swift - 通用提示组件（类似ChatGPT的Toast）

import SwiftUI

// MARK: - Tips类型
enum TipsType {
    case success
    case error
    case warning
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }
}

// MARK: - Tips视图
struct TipsView: View {
    let type: TipsType
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            Text(message)
                .font(.subheadline)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
        )
    }
}

// MARK: - Tips Modifier（在任何View上显示提示）
struct TipsModifier: ViewModifier {
    @Binding var isShowing: Bool
    let type: TipsType
    let message: String
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isShowing {
                    TipsView(type: type, message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1000)
                        .offset(y: -50)
                        .onAppear {
                            // 自动隐藏
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation {
                                    isShowing = false
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
}

// MARK: - View扩展
extension View {
    /// 显示提示
    /// - Parameters:
    ///   - isShowing: 是否显示
    ///   - type: 提示类型
    ///   - message: 提示消息
    ///   - duration: 显示时长（秒）
    func tips(
        isShowing: Binding<Bool>,
        type: TipsType,
        message: String,
        duration: Double = 2.0
    ) -> some View {
        modifier(TipsModifier(
            isShowing: isShowing,
            type: type,
            message: message,
            duration: duration
        ))
    }
}

// MARK: - 便捷方法
extension View {
    /// 成功提示
    func successTips(isShowing: Binding<Bool>, message: String = "Success", duration: Double = 2.0) -> some View {
        tips(isShowing: isShowing, type: .success, message: message, duration: duration)
    }
    
    /// 错误提示
    func errorTips(isShowing: Binding<Bool>, message: String = "Error", duration: Double = 2.0) -> some View {
        tips(isShowing: isShowing, type: .error, message: message, duration: duration)
    }
    
    /// 警告提示
    func warningTips(isShowing: Binding<Bool>, message: String = "Warning", duration: Double = 2.0) -> some View {
        tips(isShowing: isShowing, type: .warning, message: message, duration: duration)
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        TipsView(type: .success, message: "Message copied")
        TipsView(type: .error, message: "Failed to load")
        TipsView(type: .warning, message: "Please select a book")
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
