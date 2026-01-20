// ContentView.swift - 主视图（极简设计，类似 ChatGPT）

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ChatView()
            .task {
                // 在视图出现时加载书籍列表
                await appState.loadBooks()
            }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
}
