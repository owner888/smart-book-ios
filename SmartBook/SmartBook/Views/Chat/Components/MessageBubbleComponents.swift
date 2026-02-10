// MessageBubbleComponents.swift - 消息气泡子组件集合

import SwiftUI
import MarkdownUI

// MARK: - 富文本透明度扩展
extension NSMutableAttributedString {

    /// 为指定范围的文本添加透明度
    func addOpacity(_ opacity: CGFloat, range: NSRange) {
        if self.length > 0 && range.location + range.length <= self.length {
            if let currentColor = attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor {
                let newColor = currentColor.withAlphaComponent(opacity)
                addAttribute(.foregroundColor, value: newColor, range: range)
            } else {
                // 如果没有现有颜色，使用默认颜色
                addAttribute(.foregroundColor, value: UIColor.white.withAlphaComponent(opacity), range: range)
            }
        }
        
    }

    /// 为整个字符串添加透明度
    func addOpacity(_ opacity: CGFloat) {
        addOpacity(opacity, range: NSRange(location: 0, length: string.count))
    }

    /// 渐变透明度效果（文字从左到右逐渐变淡）
    func addGradientOpacity(from startOpacity: CGFloat = 1.0, to endOpacity: CGFloat = 0.3) {
        let textLength = string.count
        if textLength == 0 { return }

        for i in 0..<textLength {
            let progress = CGFloat(i) / CGFloat(textLength - 1)
            let opacity = startOpacity + (endOpacity - startOpacity) * progress
            let range = NSRange(location: i, length: 1)
            addOpacity(opacity, range: range)
        }
    }

    /// 为关键词添加透明度高亮
    func highlightKeywords(_ keywords: [String], highlightOpacity: CGFloat = 0.9) {
        let lowercasedString = string.lowercased()

        for keyword in keywords {
            let lowercasedKeyword = keyword.lowercased()
            var searchRange = NSRange(location: 0, length: lowercasedString.count)

            while let range = lowercasedString.range(of: lowercasedKeyword, options: [], range: Range(searchRange, in: lowercasedString)) {
                let nsRange = NSRange(range, in: lowercasedString)
                addOpacity(highlightOpacity, range: nsRange)

                // 更新搜索范围
                searchRange = NSRange(location: nsRange.location + nsRange.length,
                                    length: lowercasedString.count - (nsRange.location + nsRange.length))
            }
        }
    }

    /// 根据文字长度自动调整透明度（长文本变淡）
    func addLengthBasedOpacity(minOpacity: CGFloat = 0.4, maxOpacity: CGFloat = 1.0) {
        let textLength = string.count
        let opacity = max(minOpacity, maxOpacity - CGFloat(textLength) * 0.02) // 每增加50个字符透明度降低0.02
        addOpacity(opacity)
    }
}

// MARK: - 思考过程视图
struct MessageThinkingView: View {
    let thinking: String
    var colors: ThemeColors
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 头部：整栏可点击
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("Thinking...")
                    .font(.caption) // 12号
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption) // 12号
            }
            .foregroundColor(colors.primaryText)
            .padding(8)
            .contentShape(Rectangle())  // 整个区域都可以点击
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // 展开的内容
            if isExpanded {
                Text(thinking)
                    .font(.caption) // 12号
                    .foregroundColor(colors.secondaryText)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.1))
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.05))
                )
        )
    }
}

// MARK: - 消息内容视图
struct MessageContentView: View {
    let message: ChatMessage
    var colors: ThemeColors
    
    var body: some View {
        if message.role == .user {
            Text(message.content)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)  // 允许垂直扩展
        } else {
            // 使用SelectableText实现真正的文本选择
            let attributedString = markdownToAttributedString(message.content)
            SelectableText(
                attributedText: attributedString,
                textColor: UIColor(colors.primaryText),
                backgroundColor: .clear
            )
            .frame(maxWidth: .infinity, alignment: .leading)  // 占满宽度，左对齐
        }
    }
    /// 将Markdown内容转换为NSMutableAttributedString
    private func markdownToAttributedString(_ markdown: String) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString(string: "")
        var remaining = markdown
        if remaining.last == "\n" {
            remaining.removeLast()
        }

        // 正则表达式模式
        let patterns: [(String, String, NSRegularExpression.Options?)] = [
            ("codeBlock", #"```([\s\S]*?)```"#, nil),           // 代码块
            ("inlineCode", #"`([^`]+)`"#, nil),                // 行内代码
            ("bold", #"\*\*([^*]+)\*\*"#, nil),               // 粗体
            ("italic", #"\*([^*]+)\*"#, nil),                 // 斜体
            ("strikethrough", #"~~([^~]+)~~"#, nil),          // 删除线
            ("link", #"\\[([^\]]+)\\]\\(([^)]+)\\)"#, nil),   // 链接
            ("header", #"^(#{1,6})\s+(.+)$"#, .anchorsMatchLines), // 标题
            ("blockquote", #"^>\s+(.+)$"#, .anchorsMatchLines)     // 引用
        ]

        while !remaining.isEmpty {
            var foundMatch = false

            for (type, pattern, options) in patterns {
                let regex = try! NSRegularExpression(pattern: pattern, options: options ?? [])
                let nsString = remaining as NSString
                let range = NSRange(location: 0, length: nsString.length)

                if let match = regex.firstMatch(in: remaining, options: [], range: range) {
                    // 处理匹配前的普通文本
                    if match.range.location > 0 {
                        let normalText = String(remaining.prefix(match.range.location))
                        let normalAttributedString = createAttributedString(for: "normal", content: normalText)
                        attributedString.append(normalAttributedString)
                    }

                    // 处理匹配的内容
                    let elementAttributedString = createAttributedString(for: type, match: match, in: remaining)
                    attributedString.append(elementAttributedString)

                    // 更新剩余文本
                    remaining = String(remaining.suffix(from: remaining.index(remaining.startIndex, offsetBy: match.range.location + match.range.length)))
                    foundMatch = true
                    break
                }
            }

            // 如果没有找到匹配，处理剩余的普通文本
            if !foundMatch {
                let normalAttributedString = createAttributedString(for: "normal", content: remaining)
                attributedString.append(normalAttributedString)
                break
            }
        }
        
        // 只有在流式显示时才应用透明度效果
        if message.isStreaming {
            applyTransparencyEffects(to: attributedString, colors: colors)
        }
        // 注意：段落样式已经在 createAttributedString 中设置，这里不需要额外处理
        return attributedString
    }

    
    /// 计算AttributedString的精确高度
    private func calculateTextHeight(for attributedString: NSAttributedString, width: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(boundingRect.height)
    }

    /// 应用流式显示的透明度效果
    private func applyTransparencyEffects(to attributedString: NSMutableAttributedString, colors: ThemeColors) {
        let textLength = attributedString.length
        guard textLength > 0 else { return }
        var location = max(0,textLength - 3)
        let opacitys = [0.1, 0.3, 0.6]
        var index = 0
        while location >= 0 && index < opacitys.count {
            let length = min(3, textLength - location)
            attributedString.addOpacity(opacitys[index], range: NSRange(location: location, length: length))
            location -= 3
            index += 1
        }
    }

    /// 创建AttributedString
    private func createAttributedString(for type: String, content: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: content)

        // 创建紧凑的段落样式，移除底部空白
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0 // 行间距
        paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize + 3 // 动态行高
        paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize + 3 // 动态行高
        paragraphStyle.lineHeightMultiple = 1.0 // 行高倍数

        switch type {
        case "normal":
            attributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor(colors.primaryText), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))

        case "bold":
            let boldFont = UIFont.preferredFont(forTextStyle: .body)
            let boldDescriptor = boldFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? boldFont.fontDescriptor
            attributedString.addAttribute(.font, value: UIFont(descriptor: boldDescriptor, size: 0), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor(colors.primaryText), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))

        case "italic":
            let italicFont = UIFont.preferredFont(forTextStyle: .body)
            let italicDescriptor = italicFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? italicFont.fontDescriptor
            attributedString.addAttribute(.font, value: UIFont(descriptor: italicDescriptor, size: 0), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor(colors.primaryText), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))

        case "inlineCode":
            attributedString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize, weight: .regular), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor.green, range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.backgroundColor, value: UIColor(colors.secondaryText).withAlphaComponent(0.1), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))

        case "codeBlock":
            attributedString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize, weight: .regular), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor.green, range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.backgroundColor, value: UIColor(colors.secondaryText).withAlphaComponent(0.1), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))

        case "strikethrough":
            attributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor(colors.primaryText).withAlphaComponent(0.6), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))

        case "faded": // 自定义淡化效果
            attributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor(colors.primaryText).withAlphaComponent(0.4), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))

        case "link":
            attributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor.blue.withAlphaComponent(0.8), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))

        case "header":
            let level = content.prefix(while: { $0 == "#" }).count
            let titleContent = content.trimmingCharacters(in: CharacterSet(charactersIn: "# "))

            let attributedString = NSMutableAttributedString(string: titleContent)
            let textStyle: UIFont.TextStyle = switch level {
                case 1: .title1
                case 2: .title2
                case 3: .title3
                default: .headline
            }
            let headerFont = UIFont.preferredFont(forTextStyle: textStyle)
            let boldDescriptor = headerFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? headerFont.fontDescriptor
            attributedString.addAttribute(.font, value: UIFont(descriptor: boldDescriptor, size: 0), range: NSRange(location: 0, length: titleContent.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor(colors.primaryText), range: NSRange(location: 0, length: titleContent.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: titleContent.count))
            return attributedString

        case "blockquote":
            attributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor(colors.primaryText).withAlphaComponent(0.8), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))

        default:
            attributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor(colors.primaryText), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))
        }

        return attributedString
    }

    /// 创建带匹配的AttributedString
    private func createAttributedString(for type: String, match: NSTextCheckingResult, in text: String) -> NSAttributedString {
        let nsString = text as NSString

        // 创建紧凑的段落样式
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0
        paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .subheadline).pointSize + 2 // 动态行高
        paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .subheadline).pointSize + 2 // 动态行高
        paragraphStyle.lineHeightMultiple = 1.0

        switch type {
        case "codeBlock":
            let content = nsString.substring(with: match.range(at: 1))
            let attributedString = NSMutableAttributedString(string: content)
            attributedString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize, weight: .regular), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor.green, range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.backgroundColor, value: UIColor(colors.secondaryText).withAlphaComponent(0.1), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))
            return attributedString

        case "inlineCode":
            let content = nsString.substring(with: match.range(at: 1))
            let attributedString = NSMutableAttributedString(string: content)
            attributedString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize, weight: .regular), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.foregroundColor, value: UIColor.green, range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.backgroundColor, value: UIColor(colors.secondaryText).withAlphaComponent(0.1), range: NSRange(location: 0, length: content.count))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: content.count))
            return attributedString

        case "bold":
            let content = nsString.substring(with: match.range(at: 1))
            return createAttributedString(for: "bold", content: content)

        case "italic":
            let content = nsString.substring(with: match.range(at: 1))
            return createAttributedString(for: "italic", content: content)

        case "strikethrough":
            let content = nsString.substring(with: match.range(at: 1))
            return createAttributedString(for: "strikethrough", content: content)

        case "link":
            let linkText = nsString.substring(with: match.range(at: 1))
            return createAttributedString(for: "link", content: linkText)

        case "header":
            let headerMatch = nsString.substring(with: match.range)
            return createAttributedString(for: "header", content: headerMatch)

        case "blockquote":
            let content = nsString.substring(with: match.range(at: 1))
            return createAttributedString(for: "blockquote", content: content)

        default:
            return NSAttributedString(string: "")
        }
    }

}

// MARK: - 检索来源视图
struct MessageSourcesView: View {
    let sources: [RAGSource]
    var colors: ThemeColors
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 头部：整栏可点击
            HStack {
                Image(systemName: "books.vertical")
                    .foregroundColor(.green)
                Text(L("chat.sources.title", sources.count))
                    .font(.caption) // 12号
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption) // 12号
            }
            .foregroundColor(colors.primaryText)
            .padding(8)
            .contentShape(Rectangle())  // 整个区域都可以点击
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // 展开的内容
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sources.prefix(3)) { source in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(source.scorePercentage)%")
                                .font(.caption2) // 11号
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.2))
                                )
                            
                            Text(source.text)
                                .font(.caption) // 12号
                                .foregroundColor(colors.secondaryText)
                                .lineLimit(3)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.05))
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.05))
                )
        )
    }
}

// MARK: - 使用统计视图
struct MessageUsageView: View {
    let usage: UsageInfo
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 12) {
            if let model = usage.model {
                Label(model, systemImage: "cpu")
                    .font(.caption2) // 11号
            }
            
            if let tokens = usage.tokens {
                if let total = tokens.total {
                    Label(formatTokens(total), systemImage: "chart.bar")
                        .font(.caption2) // 11号
                }
                
                if let input = tokens.input {
                    Label("↗\(formatTokens(input))", systemImage: "arrow.up")
                        .font(.caption2) // 11号
                }
                
                if let output = tokens.output {
                    Label("↙\(formatTokens(output))", systemImage: "arrow.down")
                        .font(.caption2) // 11号
                }
            }
            
            if let cost = usage.cost {
                Label(String(format: "$%.4f", cost), systemImage: "dollarsign.circle")
                    .font(.caption2) // 11号
            }
        }
        .foregroundColor(colors.secondaryText)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(colors.secondaryText.opacity(0.1))
        )
    }
    
    private func formatTokens(_ num: Int) -> String {
        if num >= 1000000 {
            return String(format: "%.2fM", Double(num) / 1000000)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000)
        }
        return "\(num)"
    }
}

// MARK: - 消息操作按钮
struct MessageActionsView: View {
    var colors: ThemeColors
    var onSpeak: (() -> Void)?
    var onCopy: (() -> Void)?
    var onRegenerate: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 16) {
            if let speak = onSpeak {
                Button(action: speak) {
                    Label("朗读", systemImage: "speaker.wave.2")
                        .font(.caption) // 12号
                }
                .buttonStyle(.borderless)
            }
            
            if let copy = onCopy {
                Button(action: copy) {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.caption) // 12号
                }
                .buttonStyle(.borderless)
            }
            
            if let regenerate = onRegenerate {
                Button(action: regenerate) {
                    Label("重新生成", systemImage: "arrow.clockwise")
                        .font(.caption) // 12号
                }
                .buttonStyle(.borderless)
            }
        }
        .foregroundColor(colors.secondaryText)
    }
}

// MARK: - 助手头像视图
struct MessageAssistantHeaderView: View {
    let assistant: Assistant
    var colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(assistant.colorValue.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay {
                    Text(assistant.avatar)
                        .font(.caption) // 12号
                }
            Text(assistant.name)
                .font(.caption) // 12号
                .foregroundColor(colors.secondaryText)
        }
    }
}
