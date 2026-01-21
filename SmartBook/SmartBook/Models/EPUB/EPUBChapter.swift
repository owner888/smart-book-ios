// EPUBChapter.swift - EPUB 章节

import Foundation

/// EPUB 章节
struct EPUBChapter: Identifiable {
    let id: String
    let title: String
    let href: String
    var content: String
    let order: Int
    
    init(id: String, title: String, href: String, content: String = "", order: Int) {
        self.id = id
        self.title = title
        self.href = href
        self.content = content
        self.order = order
    }
}
