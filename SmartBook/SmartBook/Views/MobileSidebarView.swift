// MobileSidebarView.swift - 移动端侧边栏视图（iPhone专用）

import SwiftUI

// MARK: - 移动端侧边栏视图
struct MobileSidebarView: View {
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
            style: .light(colors: colors)
        )
    }
}
