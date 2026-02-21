//  MessageDisplayContent.swift
//  SmartBook
//
//  Markdown 内容解析和 AttributedString 生成

import SwiftUI
import UIKit

// MARK: - NSMutableAttributedString 透明度扩展
extension NSMutableAttributedString {
    func addOpacity(_ opacity: CGFloat, range: NSRange) {
        if self.length > 0 && range.location + range.length <= self.length {
            if let currentColor = attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor {
                let newColor = currentColor.withAlphaComponent(opacity)
                addAttribute(.foregroundColor, value: newColor, range: range)
            } else {
                addAttribute(.foregroundColor, value: UIColor.white.withAlphaComponent(opacity), range: range)
            }
        }
    }

    func addOpacity(_ opacity: CGFloat) {
        addOpacity(opacity, range: NSRange(location: 0, length: string.count))
    }
}

public class MessageDisplayContent {
    let message: ChatMessage
    let colors: ThemeColors

    init(message: ChatMessage, colors: ThemeColors) {
        self.message = message
        self.colors = colors
    }
    /// 将Markdown内容转换为NSMutableAttributedString
    func markdownToAttributedString() -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString(string: "")
        var remaining = message.content
        if remaining.last == "\n" {
            remaining.removeLast()
        }

        // 正则表达式模式
        let patterns: [(String, String, NSRegularExpression.Options?)] = [
            ("codeBlock", #"```([\s\S]*?)```"#, nil),  // 代码块
            ("inlineCode", #"`([^`]+)`"#, nil),  // 行内代码
            ("bold", #"\*\*([^*]+)\*\*"#, nil),  // 粗体
            ("italic", #"\*([^*]+)\*"#, nil),  // 斜体
            ("strikethrough", #"~~([^~]+)~~"#, nil),  // 删除线
            ("link", #"\\[([^\]]+)\\]\\(([^)]+)\\)"#, nil),  // 链接
            ("header", #"^(#{1,6})\s+(.+)$"#, .anchorsMatchLines),  // 标题
            ("blockquote", #"^>\s+(.+)$"#, .anchorsMatchLines),  // 引用
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

                    // 更新剩余文本（添加边界检查）
                    let nextIndex = match.range.location + match.range.length
                    if nextIndex < remaining.count {
                        let stringIndex = remaining.index(remaining.startIndex, offsetBy: nextIndex)
                        remaining = String(remaining.suffix(from: stringIndex))
                    } else {
                        remaining = ""
                    }
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

    /// 应用流式显示的透明度效果
    private func applyTransparencyEffects(to attributedString: NSMutableAttributedString, colors: ThemeColors) {
        let textLength = attributedString.length
        guard textLength > 0 else { return }
        var location = max(0, textLength - 3)
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
    func createAttributedString(for type: String, content: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: content)

        // 创建紧凑的段落样式，移除底部空白
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0  // 行间距
        paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize + 3  // 动态行高
        paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize + 3  // 动态行高
        paragraphStyle.lineHeightMultiple = 1.0  // 行高倍数

        switch type {
        case "normal":
            attributedString.addAttribute(
                .font,
                value: UIFont.preferredFont(forTextStyle: .body),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor(colors.primaryText),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )

        case "bold":
            let boldFont = UIFont.preferredFont(forTextStyle: .body)
            let boldDescriptor = boldFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? boldFont.fontDescriptor
            attributedString.addAttribute(
                .font,
                value: UIFont(descriptor: boldDescriptor, size: 0),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor(colors.primaryText),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )

        case "italic":
            let italicFont = UIFont.preferredFont(forTextStyle: .body)
            let italicDescriptor =
                italicFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? italicFont.fontDescriptor
            attributedString.addAttribute(
                .font,
                value: UIFont(descriptor: italicDescriptor, size: 0),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor(colors.primaryText),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )

        case "inlineCode":
            attributedString.addAttribute(
                .font,
                value: UIFont.monospacedSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize,
                    weight: .regular
                ),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor.green,
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .backgroundColor,
                value: UIColor(colors.secondaryText).withAlphaComponent(0.1),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )

        case "codeBlock":
            attributedString.addAttribute(
                .font,
                value: UIFont.monospacedSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize,
                    weight: .regular
                ),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor.green,
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .backgroundColor,
                value: UIColor(colors.secondaryText).withAlphaComponent(0.1),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )

        case "strikethrough":
            attributedString.addAttribute(
                .font,
                value: UIFont.preferredFont(forTextStyle: .body),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor(colors.primaryText).withAlphaComponent(0.6),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )

        case "faded":  // 自定义淡化效果
            attributedString.addAttribute(
                .font,
                value: UIFont.preferredFont(forTextStyle: .body),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor(colors.primaryText).withAlphaComponent(0.4),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )

        case "link":
            attributedString.addAttribute(
                .font,
                value: UIFont.preferredFont(forTextStyle: .body),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor.blue.withAlphaComponent(0.8),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )

        case "header":
            let level = content.prefix(while: { $0 == "#" }).count
            let titleContent = content.trimmingCharacters(in: CharacterSet(charactersIn: "# "))

            let attributedString = NSMutableAttributedString(string: titleContent)
            let textStyle: UIFont.TextStyle =
                switch level {
                case 1: .title1
                case 2: .title2
                case 3: .title3
                default: .headline
                }
            let headerFont = UIFont.preferredFont(forTextStyle: textStyle)
            let boldDescriptor = headerFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? headerFont.fontDescriptor
            attributedString.addAttribute(
                .font,
                value: UIFont(descriptor: boldDescriptor, size: 0),
                range: NSRange(location: 0, length: titleContent.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor(colors.primaryText),
                range: NSRange(location: 0, length: titleContent.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: titleContent.count)
            )
            return attributedString

        case "blockquote":
            attributedString.addAttribute(
                .font,
                value: UIFont.preferredFont(forTextStyle: .body),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor(colors.primaryText).withAlphaComponent(0.8),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )

        default:
            attributedString.addAttribute(
                .font,
                value: UIFont.preferredFont(forTextStyle: .body),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor(colors.primaryText),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )
        }

        return attributedString
    }

    /// 创建带匹配的AttributedString
    private func createAttributedString(for type: String, match: NSTextCheckingResult, in text: String)
        -> NSAttributedString
    {
        let nsString = text as NSString

        // 创建紧凑的段落样式
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0
        paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .subheadline).pointSize + 2  // 动态行高
        paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .subheadline).pointSize + 2  // 动态行高
        paragraphStyle.lineHeightMultiple = 1.0

        switch type {
        case "codeBlock":
            let content = nsString.substring(with: match.range(at: 1))
            let attributedString = NSMutableAttributedString(string: content)
            attributedString.addAttribute(
                .font,
                value: UIFont.monospacedSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize,
                    weight: .regular
                ),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor.green,
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .backgroundColor,
                value: UIColor(colors.secondaryText).withAlphaComponent(0.1),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )
            return attributedString

        case "inlineCode":
            let content = nsString.substring(with: match.range(at: 1))
            let attributedString = NSMutableAttributedString(string: content)
            attributedString.addAttribute(
                .font,
                value: UIFont.monospacedSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize,
                    weight: .regular
                ),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor.green,
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .backgroundColor,
                value: UIColor(colors.secondaryText).withAlphaComponent(0.1),
                range: NSRange(location: 0, length: content.count)
            )
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: content.count)
            )
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
