// TXTParser.swift - TXT 文本解析器

import Foundation

/// TXT 元数据（从文件名或内容推断）
struct TXTMetadata {
    let title: String?
    let author: String?
    let encoding: String.Encoding
}

/// TXT 章节信息
struct TXTChapter {
    let title: String
    let content: String
    let startIndex: Int
}

/// TXT 解析器
class TXTParser {
    
    // MARK: - 元数据解析
    
    /// 解析 TXT 元数据（iOS 版本）
    static func parseMetadataForiOS(from path: String) -> TXTMetadata {
        let filename = (path as NSString).lastPathComponent
        let defaultTitle = ((filename as NSString).deletingPathExtension)
        
        // 尝试从内容中提取标题和作者
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return TXTMetadata(title: defaultTitle, author: nil, encoding: .utf8)
        }
        
        let lines = content.components(separatedBy: .newlines)
        var title: String?
        var author: String?
        
        // 简单启发式：前几行可能包含标题和作者
        for (index, line) in lines.prefix(10).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            // 第一个非空行可能是标题
            if title == nil && index < 3 {
                title = trimmed
            }
            
            // 检查是否包含"作者"关键词
            if author == nil {
                if trimmed.contains("作者：") || trimmed.contains("作者:") {
                    author = trimmed.replacingOccurrences(of: "作者：", with: "")
                        .replacingOccurrences(of: "作者:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("by ") || trimmed.hasPrefix("By ") {
                    author = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        return TXTMetadata(
            title: title ?? defaultTitle,
            author: author,
            encoding: .utf8
        )
    }
    
    // MARK: - 内容提取
    
    /// 读取 TXT 全文
    static func extractText(from path: String) -> String? {
        // 尝试多种编码（iOS 常用）
        let encodings: [String.Encoding] = [
            .utf8,          // UTF-8（最常用）
            .utf16,         // UTF-16
            .unicode,       // Unicode
            .ascii,         // ASCII
            .isoLatin1,     // ISO-8859-1
            .shiftJIS       // 日文
        ]
        
        for encoding in encodings {
            if let content = try? String(contentsOfFile: path, encoding: encoding) {
                return content
            }
        }
        
        return nil
    }
    
    // MARK: - 章节分割
    
    /// 智能分割章节
    /// 支持多种章节标记：第X章、Chapter X、卷X等
    static func splitIntoChapters(content: String) -> [TXTChapter] {
        let lines = content.components(separatedBy: .newlines)
        var chapters: [TXTChapter] = []
        var currentChapter: String?
        var currentContent: [String] = []
        var startIndex = 0
        
        // 章节标题正则模式
        let patterns = [
            "^第[零一二三四五六七八九十百千万\\d]+[章节回]",  // 第X章
            "^Chapter\\s+\\d+",                              // Chapter X
            "^CHAPTER\\s+\\d+",                              // CHAPTER X
            "^卷[零一二三四五六七八九十\\d]+",                 // 卷X
            "^第[零一二三四五六七八九十百千万\\d]+部分"         // 第X部分
        ]
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 检查是否是章节标题
            var isChapterTitle = false
            for pattern in patterns {
                if let _ = trimmed.range(of: pattern, options: .regularExpression) {
                    isChapterTitle = true
                    break
                }
            }
            
            if isChapterTitle && !trimmed.isEmpty {
                // 保存上一章
                if let chapterTitle = currentChapter, !currentContent.isEmpty {
                    chapters.append(TXTChapter(
                        title: chapterTitle,
                        content: currentContent.joined(separator: "\n"),
                        startIndex: startIndex
                    ))
                }
                
                // 开始新章
                currentChapter = trimmed
                currentContent = []
                startIndex = index
            } else {
                currentContent.append(line)
            }
        }
        
        // 保存最后一章
        if let chapterTitle = currentChapter, !currentContent.isEmpty {
            chapters.append(TXTChapter(
                title: chapterTitle,
                content: currentContent.joined(separator: "\n"),
                startIndex: startIndex
            ))
        }
        
        // 如果没有识别出章节，将整本书作为一章
        if chapters.isEmpty {
            chapters.append(TXTChapter(
                title: "全文",
                content: content,
                startIndex: 0
            ))
        }
        
        return chapters
    }
    
    /// 获取章节数量
    static func getChapterCount(from path: String) -> Int {
        guard let content = extractText(from: path) else {
            return 0
        }
        
        return splitIntoChapters(content: content).count
    }
}
