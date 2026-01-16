// ContentView.swift - 主视图（极简设计，类似 ChatGPT）

import SwiftUI

struct ContentView: View {
    var body: some View {
        ChatView()
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(ThemeManager.shared)
}
