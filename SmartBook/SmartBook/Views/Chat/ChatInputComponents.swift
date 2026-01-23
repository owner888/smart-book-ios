// ChatInputComponents.swift - 聊天输入组件

import SwiftUI

// MARK: - 书籍状态栏
struct BookContextBar: View {
    let book: Book
    var colors: ThemeColors = .dark
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.fill")
                .foregroundColor(.green)

            Text(String(format: L("chat.readingBook"), book.title))
                .font(.caption)
                .foregroundColor(colors.primaryText.opacity(0.8))
                .lineLimit(1)

            Spacer()

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(colors.secondaryText)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(colors.secondaryText.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(colors.cardBackground)
    }
}

// MARK: - 输入栏
struct InputBar: View {
    @Binding var text: String
    @Binding var isConversationMode: Bool
    var isFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let speechService: SpeechService
    var selectedBook: Book?
    var colors: ThemeColors = .dark
    let onSend: () -> Void
    let onVoice: () -> Void
    let onConversation: () -> Void
    let onSelectBook: () -> Void
    let onClearHistory: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：书籍选择器
            Button(action: onSelectBook) {
                HStack(spacing: 4) {
                    if let book = selectedBook {
                        Image(systemName: "book.fill")
                            .font(.title3)
                    } else {
                        Image(systemName: "books.vertical")
                            .font(.title3)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(
                    selectedBook != nil ? .green : colors.secondaryText
                )
            }
            .buttonStyle(.glassIcon)

            // 中间：输入框
            TextField(L("chat.placeholder"), text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colors.inputBackground)
                }
                .foregroundColor(colors.primaryText)
                .focused(isFocused)
                .lineLimit(1...5)

            // 右侧：功能按钮
            HStack(spacing: 8) {
                // 语音输入
                Button(action: onVoice) {
                    Image(
                        systemName: speechService.isRecording
                            ? "stop.circle.fill" : "mic.circle"
                    )
                    .font(.title2)
                            .foregroundColor(
                                text.isEmpty ? colors.secondaryText : .green
                            )
                    .symbolEffect(.bounce, value: speechService.isRecording)
                }
                .buttonStyle(.glassIcon)

                // 发送按钮
                Button(action: onSend) {
                    if isLoading {
                        ProgressView()
                            .tint(colors.primaryText)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(
                                text.isEmpty ? colors.secondaryText : .green
                            )
                    }
                }
                .buttonStyle(.glassIcon)
                .disabled(isLoading || text.isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(colors.cardBackground)
    }
}
