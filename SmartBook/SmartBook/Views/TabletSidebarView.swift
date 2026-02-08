// TabletSidebarView.swift - 平板端侧边栏视图（iPad/macOS专用，Journal风格）

import MapKit
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
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Insights 卡片
                    InsightsCard()

                    // Places 卡片
                    PlacesCard()

                    // Journals 部分
                    JournalsSection(
                        historyService: historyService,
                        viewModel: viewModel,
                        onSelectChat: onSelectChat
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(
            Color(red: 0.1, green: 0.1, blue: 0.12)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Insights 卡片
struct InsightsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insights")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Text("0")
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Entries")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Text("This Year")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.45, blue: 0.85),
                    Color(red: 0.45, green: 0.35, blue: 0.75),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

// MARK: - Places 卡片
struct PlacesCard: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Places")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Map(coordinateRegion: $region, interactionModes: [])
                .frame(height: 120)
                .disabled(true)
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Journals 部分
struct JournalsSection: View {
    var historyService: ChatHistoryService?
    var viewModel: ChatViewModel?
    var onSelectChat: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Text("Journals")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Button(action: {
                    if let viewModel = viewModel {
                        viewModel.startNewConversation()
                        onSelectChat()
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 4)

            // Journal 列表项
            if let historyService = historyService, let viewModel = viewModel {
                // 使用现有的对话历史
                ChatHistoryJournalListView(
                    historyService: historyService,
                    viewModel: viewModel,
                    onSelectConversation: onSelectChat
                )
            } else {
                // 默认的 Journal 项
                JournalItemView(
                    icon: "🦋",
                    title: "Journal",
                    count: 0,
                    isSelected: true
                )
            }
        }
    }
}

// MARK: - Journal 列表项
struct JournalItemView: View {
    let icon: String
    let title: String
    let count: Int
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Text(icon)
                .font(.system(size: 24))
                .frame(width: 32, height: 32)

            // 标题
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            // 计数
            Text("\(count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
        )
    }
}

// MARK: - 聊天历史的 Journal 风格列表
struct ChatHistoryJournalListView: View {
    var historyService: ChatHistoryService
    var viewModel: ChatViewModel
    var onSelectConversation: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ForEach(historyService.conversations) { conversation in
                Button(action: {
                    viewModel.switchToConversation(conversation)
                    onSelectConversation()
                }) {
                    JournalItemView(
                        icon: "📝",
                        title: conversation.title,
                        count: conversation.messages?.count ?? 0,
                        isSelected: historyService.currentConversation?.id == conversation.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
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
