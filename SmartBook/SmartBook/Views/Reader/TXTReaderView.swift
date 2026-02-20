// TXTReaderView.swift - TXT 文本阅读器视图

import SwiftUI

struct TXTReaderView: View {
    let txtURL: URL
    @State private var content: String = ""
    @State private var chapters: [TXTChapter] = []
    @State private var currentChapterIndex: Int = 0
    @State private var fontSize: CGFloat = 18
    @State private var lineSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            // 章节导航（如果有章节）
            if chapters.count > 1 {
                chapterPicker
            }

            // 文本内容
            ScrollView {
                Text(currentChapterContent)
                    .font(.system(size: fontSize))
                    .lineSpacing(lineSpacing)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 阅读控制栏
            readerControlBar
        }
        .navigationTitle(chapters.isEmpty ? "正在加载..." : chapters[currentChapterIndex].title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContent()
        }
    }

    // MARK: - 章节选择器

    private var chapterPicker: some View {
        Picker("章节", selection: $currentChapterIndex) {
            ForEach(0..<chapters.count, id: \.self) { index in
                Text(chapters[index].title)
                    .tag(index)
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - 控制栏

    private var readerControlBar: some View {
        HStack {
            // 减小字号
            Button(action: { fontSize = max(12, fontSize - 2) }) {
                Image(systemName: "textformat.size.smaller")
                    .font(.title3)
            }

            Spacer()

            // 字号显示
            Text("\(Int(fontSize))pt")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // 增大字号
            Button(action: { fontSize = min(32, fontSize + 2) }) {
                Image(systemName: "textformat.size.larger")
                    .font(.title3)
            }

            Spacer()

            // 上一章
            Button(action: { previousChapter() }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .disabled(currentChapterIndex == 0)

            Spacer()

            // 下一章
            Button(action: { nextChapter() }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .disabled(currentChapterIndex == chapters.count - 1)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - 计算属性

    private var currentChapterContent: String {
        guard !chapters.isEmpty, currentChapterIndex < chapters.count else {
            return content
        }
        return chapters[currentChapterIndex].content
    }

    // MARK: - 章节导航

    private func previousChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
    }

    private func nextChapter() {
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
    }

    // MARK: - 加载内容

    private func loadContent() async {
        guard let loadedContent = TXTParser.extractText(from: txtURL.path) else {
            content = "无法读取文件"
            return
        }

        content = loadedContent
        chapters = TXTParser.splitIntoChapters(content: loadedContent)

        Logger.info("TXT 文件加载完成，共 \(chapters.count) 章")
    }
}

#Preview {
    NavigationStack {
        if let sampleURL = Bundle.main.url(forResource: "sample", withExtension: "txt") {
            TXTReaderView(txtURL: sampleURL)
        } else {
            Text("没有找到示例 TXT")
        }
    }
}
