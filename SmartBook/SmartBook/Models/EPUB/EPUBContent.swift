// EPUBContent.swift - EPUB 内容

import Foundation

/// EPUB 内容（包含元数据和章节）
struct EPUBContent {
    var metadata: EPUBMetadata
    var chapters: [EPUBChapter]
    var spine: [String] // 按阅读顺序排列的章节ID
}
