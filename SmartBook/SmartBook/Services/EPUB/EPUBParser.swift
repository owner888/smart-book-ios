// EPUBParser.swift - EPUB 解析器（主协调器）

import Foundation
import UIKit

/// EPUB 解析器 - 协调各个解析组件
class EPUBParser {
    
    // MARK: - 元数据解析
    
    /// 解析 EPUB 文件元数据（iOS 专用）
    static func parseMetadataForiOS(from epubPath: String) -> EPUBMetadata {
        var metadata = EPUBMetadata()
        
        guard FileManager.default.fileExists(atPath: epubPath) else {
            Logger.warn("EPUB file not found: \(epubPath)")
            return metadata
        }
        
        guard let archive = ZIPArchive(url: URL(fileURLWithPath: epubPath)) else {
            Logger.error("Failed to open EPUB archive")
            return metadata
        }
        
        // 创建临时目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // 解压所有文件
        do {
            for entry in archive.entries {
                if entry.isDirectory { continue }
                
                let destinationURL = tempDir.appendingPathComponent(entry.path)
                try FileManager.default.createDirectory(
                    at: destinationURL.deletingLastPathComponent(), 
                    withIntermediateDirectories: true
                )
                try archive.extract(entry, to: destinationURL)
            }
            
            // 读取 container.xml
            let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
            guard let opfRelativePath = EPUBMetadataParser.parseContainerXML(at: containerPath) else {
                return metadata
            }
            
            // 读取 OPF 文件
            let opfPath = tempDir.appendingPathComponent(opfRelativePath)
            let opfDir = opfPath.deletingLastPathComponent()
            metadata = EPUBMetadataParser.parseOPFFile(at: opfPath, opfDir: opfDir)
            
        } catch {
            Logger.error("Error extracting EPUB: \(error)")
        }
        
        return metadata
    }
    
    // MARK: - 内容解析
    
    /// 解析 EPUB 完整内容（元数据 + 章节）
    static func parseContent(from epubPath: String) -> EPUBContent? {
        guard FileManager.default.fileExists(atPath: epubPath) else {
            Logger.warn("EPUB file not found: \(epubPath)")
            return nil
        }
        
        guard let archive = ZIPArchive(url: URL(fileURLWithPath: epubPath)) else {
            Logger.error("Failed to open EPUB archive")
            return nil
        }
        
        // 创建临时目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        do {
            // 解压所有文件
            for entry in archive.entries {
                if entry.isDirectory { continue }
                
                let destinationURL = tempDir.appendingPathComponent(entry.path)
                try FileManager.default.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try archive.extract(entry, to: destinationURL)
            }
            
            // 读取 container.xml
            let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
            guard let opfRelativePath = EPUBMetadataParser.parseContainerXML(at: containerPath) else {
                return nil
            }
            
            // 读取 OPF 文件
            let opfPath = tempDir.appendingPathComponent(opfRelativePath)
            let opfDir = opfPath.deletingLastPathComponent()
            
            guard let opfData = try? Data(contentsOf: opfPath),
                  let opfXML = String(data: opfData, encoding: .utf8) else {
                return nil
            }
            
            // 解析元数据
            let metadata = EPUBMetadataParser.parseOPFFile(at: opfPath, opfDir: opfDir)
            
            // 解析 manifest（资源清单）
            let manifest = EPUBContentParser.parseManifest(from: opfXML)
            
            // 解析 spine（阅读顺序）
            let spine = EPUBContentParser.parseSpine(from: opfXML)
            
            // 解析 TOC（目录）
            let tocMap = EPUBContentParser.parseTOC(from: opfXML, manifest: manifest, opfDir: opfDir)
            
            // 加载章节内容
            var chapters: [EPUBChapter] = []
            for (index, itemRef) in spine.enumerated() {
                guard let href = manifest[itemRef] else { continue }
                
                let chapterPath = opfDir.appendingPathComponent(href)
                var content = ""
                
                if let htmlData = try? Data(contentsOf: chapterPath),
                   let htmlString = String(data: htmlData, encoding: .utf8) {
                    content = EPUBContentParser.extractTextFromHTML(htmlString)
                }
                
                // 获取章节标题
                let title = tocMap[href] ?? tocMap[itemRef] ?? "第 \(index + 1) 章"
                
                let chapter = EPUBChapter(
                    id: itemRef,
                    title: title,
                    href: href,
                    content: content,
                    order: index
                )
                chapters.append(chapter)
            }
            
            return EPUBContent(metadata: metadata, chapters: chapters, spine: spine)
            
        } catch {
            Logger.error("Error parsing EPUB content: \(error)")
            return nil
        }
    }
    
    // MARK: - 封面缓存
    
    /// 提取并保存封面图片到缓存目录
    static func extractAndCacheCover(from epubPath: String, bookId: String) -> URL? {
        return EPUBCoverCache.extractAndCacheCover(from: epubPath, bookId: bookId)
    }
    
    /// 获取缓存的封面图片路径
    static func getCachedCoverPath(for bookId: String) -> URL? {
        return EPUBCoverCache.getCachedCoverPath(for: bookId)
    }
    
    // MARK: - HTML 文本提取（保持向后兼容）
    
    /// 从 HTML 中提取纯文本
    static func extractTextFromHTML(_ html: String) -> String {
        return EPUBContentParser.extractTextFromHTML(html)
    }
}
