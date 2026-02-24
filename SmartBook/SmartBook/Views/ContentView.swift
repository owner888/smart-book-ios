// ContentView.swift - 主视图（极简设计，类似 ChatGPT）

import SwiftUI

struct ContentView: View {
    @Environment(BookState.self) private var bookState
    @Environment(BookService.self) private var bookService

    // AI 数据共享同意状态
    @AppStorage(AppConfig.Keys.aiDataConsentGiven) private var aiDataConsentGiven = false
    @State private var showConsentView = false

    var body: some View {
        ChatView()
            .task {
                // 在视图出现时加载书籍列表
                await bookState.loadBooks(using: bookService)
            }
            .fullScreenCover(isPresented: $showConsentView) {
                AIDataConsentView(
                    hasConsented: $aiDataConsentGiven,
                    onAgree: {
                        aiDataConsentGiven = true
                        showConsentView = false
                    },
                    onDecline: {
                        // 用户拒绝，退出 App
                        exit(0)
                    }
                )
                .interactiveDismissDisabled(true) // 禁止下滑关闭
            }
            .onAppear {
                // 如果用户还没有同意过，显示同意弹窗
                if !aiDataConsentGiven {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showConsentView = true
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
