// PDFParser.swift - PDF 解析器
// 使用 iOS 原生 PDFKit 解析 PDF 文件

import Foundation
import PDFKit

/// PDF 元数据
struct PDFMetadata {
    let title: String?
    let author: String?
    let subject: String?
    let keywords: String?
    let creator: String?
    let producer: String?
    let creationDate: Date?
    let modificationDate: Date?
}

/// PDF 页面信息
struct PDFPageInfo {
    let pageNumber: Int
    let text: String
    let bounds: CGRect
}

/// PDF 解析器
class PDFParser {
    
    // MARK: - 元数据解析
    
    /// 解析 PDF 元数据（iOS 版本）
    static func parseMetadataForiOS(from path: String) -> PDFMetadata {
        guard let url = URL(string: "file://\(path)"),
              let document = PDFDocument(url: url) else {
            return PDFMetadata(
                title: nil,
                author: nil,
                subject: nil,
                keywords: nil,
                creator: nil,
                producer: nil,
                creationDate: nil,
                modificationDate: nil
            )
        }
        
        return PDFMetadata(
            title: document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
            author: document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String,
            subject: document.documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String,
            keywords: document.documentAttributes?[PDFDocumentAttribute.keywordsAttribute] as? String,
            creator: document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String,
            producer: document.documentAttributes?[PDFDocumentAttribute.producerAttribute] as? String,
            creationDate: document.documentAttributes?[PDFDocumentAttribute.creationDateAttribute] as? Date,
            modificationDate: document.documentAttributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date
        )
    }
    
    // MARK: - 内容提取
    
    /// 提取 PDF 所有文本内容
    static func extractText(from path: String) -> String? {
        guard let url = URL(string: "file://\(path)"),
              let document = PDFDocument(url: url) else {
            return nil
        }
        
        var fullText = ""
        
        for i in 0..<document.pageCount {
            if let page = document.page(at: i),
               let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }
        
        return fullText.isEmpty ? nil : fullText
    }
    
    /// 提取指定页的文本
    static func extractText(from path: String, page pageNumber: Int) -> String? {
        guard let url = URL(string: "file://\(path)"),
              let document = PDFDocument(url: url),
              pageNumber >= 0,
              pageNumber < document.pageCount,
              let page = document.page(at: pageNumber) else {
            return nil
        }
        
        return page.string
    }
    
    /// 提取页面范围的文本
    static func extractText(from path: String, pageRange: Range<Int>) -> String? {
        guard let url = URL(string: "file://\(path)"),
              let document = PDFDocument(url: url) else {
            return nil
        }
        
        var text = ""
        
        for i in pageRange {
            guard i >= 0, i < document.pageCount,
                  let page = document.page(at: i),
                  let pageText = page.string else {
                continue
            }
            
            text += pageText + "\n\n"
        }
        
        return text.isEmpty ? nil : text
    }
    
    // MARK: - PDF 文档信息
    
    /// 获取 PDF 页数
    static func getPageCount(from path: String) -> Int {
        guard let url = URL(string: "file://\(path)"),
              let document = PDFDocument(url: url) else {
            return 0
        }
        
        return document.pageCount
    }
    
    /// 获取所有页面信息
    static func getPageInfos(from path: String) -> [PDFPageInfo] {
        guard let url = URL(string: "file://\(path)"),
              let document = PDFDocument(url: url) else {
            return []
        }
        
        var pages: [PDFPageInfo] = []
        
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                pages.append(PDFPageInfo(
                    pageNumber: i,
                    text: page.string ?? "",
                    bounds: page.bounds(for: .mediaBox)
                ))
            }
        }
        
        return pages
    }
    
    // MARK: - 封面提取
    
    /// 提取并缓存 PDF 封面（第一页）
    static func extractAndCacheCover(from path: String, bookId: String) -> URL? {
        guard let url = URL(string: "file://\(path)"),
              let document = PDFDocument(url: url),
              let firstPage = document.page(at: 0) else {
            return nil
        }
        
        // 生成缩略图
        let pageRect = firstPage.bounds(for: .mediaBox)
        let targetSize = CGSize(width: 300, height: 450)
        
        // 计算缩放比例
        let scale = min(targetSize.width / pageRect.width, targetSize.height / pageRect.height)
        let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: scaledSize))
            
            ctx.cgContext.translateBy(x: 0, y: scaledSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            
            firstPage.draw(with: .mediaBox, to: ctx.cgContext)
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        #else
        // macOS 版本（如果需要）
        return nil
        #endif
        
        // 保存到缓存
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Covers")
        
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        let coverPath = cacheDir.appendingPathComponent("\(bookId).jpg")
        
        try? imageData.write(to: coverPath)
        
        return coverPath
    }
    
    /// 获取缓存的封面路径
    static func getCachedCoverPath(for bookId: String) -> URL? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Covers")
        
        let coverPath = cacheDir.appendingPathComponent("\(bookId).jpg")
        
        return FileManager.default.fileExists(atPath: coverPath.path) ? coverPath : nil
    }
}
