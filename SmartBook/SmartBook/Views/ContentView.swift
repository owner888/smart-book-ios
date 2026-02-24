// ContentView.swift - 主视图（极简设计，类似 ChatGPT）

import SwiftUI

struct ContentView: View {
    @Environment(BookState.self) private var bookState
    @Environment(BookService.self) private var bookService

    // AI 数据共享同意状态
    @AppStorage(AppConfig.Keys.aiDataConsentGiven) private var aiDataConsentGiven = false
    @State private var showConsentView = false

    var body: some View {
        ZStack {
            ChatView()
                .task {
                    // 在视图出现时加载书籍列表
                    await bookState.loadBooks(using: bookService)
                }

            // AI 数据共享同意弹窗（首次启动时显示）
            if showConsentView {
                AIDataConsentView(
                    hasConsented: $aiDataConsentGiven,
                    onAgree: {
                        aiDataConsentGiven = true
                        withAnimation(.easeOut(duration: 0.3)) {
                            showConsentView = false
                        }
                    },
                    onDecline: {
                        // 用户拒绝，仍然关闭弹窗，但不设置同意标志
                        // 用户可以使用阅读功能，但 AI 功能将被限制
                        withAnimation(.easeOut(duration: 0.3)) {
                            showConsentView = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onAppear {
            // 如果用户还没有同意过，显示同意弹窗
            if !aiDataConsentGiven {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showConsentView = true
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(BookState())
        .environment(ThemeManager.shared)
}
