// ContentView.swift - 主视图（极简设计，类似 ChatGPT）

import SwiftUI

struct ContentView: View {
    @Environment(BookState.self) private var bookState
    @Environment(BookService.self) private var bookService
    
    var body: some View {
        ChatView()
            .task {
                // 在视图出现时加载书籍列表
                await bookState.loadBooks(using: bookService)
            }
    }
}

#Preview {
    ContentView()
        .environment(BookState())
        .environment(ThemeManager.shared)
}
