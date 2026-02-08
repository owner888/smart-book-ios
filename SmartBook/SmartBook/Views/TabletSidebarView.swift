// TabletSidebarView.swift - 平板端侧边栏视图（iPad/macOS专用，Journal风格）

import SwiftUI

// MARK: - 平板端侧边栏视图
struct TabletSidebarView: View {
    var colors: ThemeColors
    var historyService: ChatHistoryService?
    var viewModel: ChatViewModel?
    var onSelectChat: () -> Void
    var onSelectBookshelf: () -> Void
    var onSelectSettings: () -> Void
    
    var body: some View {
        SidebarContent(
            colors: colors,
            historyService: historyService,
            viewModel: viewModel,
            onSelectChat: onSelectChat,
            onSelectBookshelf: onSelectBookshelf,
            onSelectSettings: onSelectSettings,
            style: .dark
        )
    }
}

// MARK: - 预览
#Preview {
    TabletSidebarView(
        colors: .light,
        historyService: nil,
        viewModel: nil,
        onSelectChat: {},
        onSelectBookshelf: {},
        onSelectSettings: {}
    )
    .frame(width: 320)
}
