// EPUBParser.swift - EPUB 元数据解析器（纯 Swift 实现，iOS 兼容）

import Foundation
import UIKit
import Compression

/// EPUB 元数据
struct EPUBMetadata {
    var title: String?
    var author: String?
    var publisher: String?
    var language: String?
    var description: String?
    var coverImage: UIImage?
    var localCoverPath: String?
}

/// EPUB 解析器
class EPUBParser {
    
    /// 解析 EPUB 文件元数据（iOS 专用）
    static func parseMetadataForiOS(from epubPath: String) -> EPUBMetadata {
        var metadata = EPUBMetadata()
        
        guard FileManager.default.fileExists(atPath: epubPath) else {
            print("EPUB file not found: \(epubPath)")
            return metadata
        }
        
        guard let archive = ZIPArchive(url: URL(fileURLWithPath: epubPath)) else {
            print("Failed to open EPUB archive")
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
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), 
                                                        withIntermediateDirectories: true)
                try archive.extract(entry, to: destinationURL)
            }
            
            // 读取 container.xml
            let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
            guard let opfRelativePath = parseContainerXML(at: containerPath) else {
                return metadata
            }
            
            // 读取 OPF 文件
            let opfPath = tempDir.appendingPathComponent(opfRelativePath)
            let opfDir = opfPath.deletingLastPathComponent()
            metadata = parseOPFFile(at: opfPath, opfDir: opfDir)
            
        } catch {
            print("Error extracting EPUB: \(error)")
        }
        
        return metadata
    }
    
    /// 解析 container.xml 获取 OPF 文件路径
    private static func parseContainerXML(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let xmlString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let pattern = #"full-path\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
              let range = Range(match.range(at: 1), in: xmlString) else {
            return nil
        }
        
        return String(xmlString[range])
    }
    
    /// 解析 OPF 文件获取元数据
    private static func parseOPFFile(at url: URL, opfDir: URL) -> EPUBMetadata {
        var metadata = EPUBMetadata()
        
        guard let data = try? Data(contentsOf: url),
              let xmlString = String(data: data, encoding: .utf8) else {
            return metadata
        }
        
        metadata.title = extractXMLElement(from: xmlString, tag: "dc:title")
            ?? extractXMLElement(from: xmlString, tag: "title")
        
        metadata.author = extractXMLElement(from: xmlString, tag: "dc:creator")
            ?? extractXMLElement(from: xmlString, tag: "creator")
        
        metadata.publisher = extractXMLElement(from: xmlString, tag: "dc:publisher")
            ?? extractXMLElement(from: xmlString, tag: "publisher")
        
        metadata.language = extractXMLElement(from: xmlString, tag: "dc:language")
            ?? extractXMLElement(from: xmlString, tag: "language")
        
        metadata.description = extractXMLElement(from: xmlString, tag: "dc:description")
            ?? extractXMLElement(from: xmlString, tag: "description")
        
        if let coverPath = extractCoverImagePath(from: xmlString, opfDir: opfDir) {
            if let imageData = try? Data(contentsOf: URL(fileURLWithPath: coverPath)) {
                metadata.coverImage = UIImage(data: imageData)
            }
        }
        
        return metadata
    }
    
    /// 从 XML 中提取指定标签的内容
    private static func extractXMLElement(from xml: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>([^<]*)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              let range = Range(match.range(at: 1), in: xml) else {
            return nil
        }
        
        let content = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }
    
    /// 提取封面图片路径
    private static func extractCoverImagePath(from xml: String, opfDir: URL) -> String? {
        var coverId: String?
        
        // 方法1: 查找 <meta name="cover" content="xxx"/>
        let metaPattern = #"<meta\s+name\s*=\s*["']cover["'][^>]*content\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: metaPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
           let range = Range(match.range(at: 1), in: xml) {
            coverId = String(xml[range])
        }
        
        // 方法2: 查找 properties="cover-image" 的 item
        if coverId == nil {
            let coverItemPattern = #"<item[^>]+properties\s*=\s*["'][^"']*cover-image[^"']*["'][^>]*href\s*=\s*["']([^"']+)["']"#
            if let regex = try? NSRegularExpression(pattern: coverItemPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
               let range = Range(match.range(at: 1), in: xml) {
                let href = String(xml[range])
                return opfDir.appendingPathComponent(href).path
            }
            
            let coverItemPattern2 = #"<item[^>]+href\s*=\s*["']([^"']+)["'][^>]*properties\s*=\s*["'][^"']*cover-image[^"']*["']"#
            if let regex = try? NSRegularExpression(pattern: coverItemPattern2, options: .caseInsensitive),
               let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
               let range = Range(match.range(at: 1), in: xml) {
                let href = String(xml[range])
                return opfDir.appendingPathComponent(href).path
            }
        }
        
        // 根据 coverId 查找 item
        if let id = coverId {
            let itemPattern = "<item[^>]+id\\s*=\\s*[\"']\(id)[\"'][^>]*href\\s*=\\s*[\"']([^\"']+)[\"']"
            if let regex = try? NSRegularExpression(pattern: itemPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
               let range = Range(match.range(at: 1), in: xml) {
                let href = String(xml[range])
                return opfDir.appendingPathComponent(href).path
            }
            
            let itemPattern2 = "<item[^>]+href\\s*=\\s*[\"']([^\"']+)[\"'][^>]*id\\s*=\\s*[\"']\(id)[\"']"
            if let regex = try? NSRegularExpression(pattern: itemPattern2, options: .caseInsensitive),
               let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
               let range = Range(match.range(at: 1), in: xml) {
                let href = String(xml[range])
                return opfDir.appendingPathComponent(href).path
            }
        }
        
        // 方法3: 查找常见的封面文件名
        let itemHrefPattern = #"<item[^>]+href\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: itemHrefPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            for match in matches {
                if let range = Range(match.range(at: 1), in: xml) {
                    let href = String(xml[range])
                    if href.lowercased().contains("cover") && 
                       (href.hasSuffix(".jpg") || href.hasSuffix(".jpeg") || href.hasSuffix(".png")) {
                        let coverPath = opfDir.appendingPathComponent(href).path
                        if FileManager.default.fileExists(atPath: coverPath) {
                            return coverPath
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// 提取并保存封面图片到缓存目录
    static func extractAndCacheCover(from epubPath: String, bookId: String) -> URL? {
        let metadata = parseMetadataForiOS(from: epubPath)
        
        guard let coverImage = metadata.coverImage,
              let imageData = coverImage.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let coversDir = cacheDir.appendingPathComponent("BookCovers")
        
        try? FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
        
        let safeBookId = bookId.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let coverURL = coversDir.appendingPathComponent("\(safeBookId).jpg")
        
        do {
            try imageData.write(to: coverURL)
            return coverURL
        } catch {
            print("Failed to save cover image: \(error)")
            return nil
        }
    }
    
    /// 获取缓存的封面图片路径
    static func getCachedCoverPath(for bookId: String) -> URL? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let safeBookId = bookId.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let coverURL = cacheDir.appendingPathComponent("BookCovers/\(safeBookId).jpg")
        
        if FileManager.default.fileExists(atPath: coverURL.path) {
            return coverURL
        }
        return nil
    }
}

// MARK: - ZIP Archive 读取器（纯 Swift 实现）
class ZIPArchive {
    let url: URL
    private var fileHandle: FileHandle?
    private(set) var entries: [Entry] = []
    
    struct Entry {
        let path: String
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let offset: UInt32
        let compressionMethod: UInt16
        var isDirectory: Bool { path.hasSuffix("/") }
    }
    
    init?(url: URL) {
        self.url = url
        
        do {
            fileHandle = try FileHandle(forReadingFrom: url)
            try parseEntries()
        } catch {
            print("Failed to open archive: \(error)")
            return nil
        }
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    // MARK: - 安全读取方法（处理非对齐内存）
    
    private func readUInt16(from data: Data, at offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    
    private func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset]) | 
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }
    
    private func parseEntries() throws {
        guard let handle = fileHandle else { return }
        
        // 获取文件大小
        try handle.seekToEnd()
        let fileSize = try handle.offset()
        
        // EOCD 最小 22 字节，最大 22 + 65535
        let searchSize = Swift.min(fileSize, 22 + 65535)
        try handle.seek(toOffset: fileSize - searchSize)
        let searchData = handle.readData(ofLength: Int(searchSize))
        
        // 查找 EOCD 签名 (0x06054b50)
        var eocdOffset: Int?
        for i in stride(from: searchData.count - 22, through: 0, by: -1) {
            if searchData[i] == 0x50 && searchData[i+1] == 0x4b && 
               searchData[i+2] == 0x05 && searchData[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        
        guard let offset = eocdOffset else {
            throw NSError(domain: "ZIPArchive", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP file"])
        }
        
        // 读取 Central Directory 偏移（使用安全方法）
        let cdOffset = readUInt32(from: searchData, at: offset + 16)
        
        // 读取 Central Directory
        try handle.seek(toOffset: UInt64(cdOffset))
        
        while true {
            let sigData = handle.readData(ofLength: 4)
            if sigData.count < 4 { break }
            
            let sig = readUInt32(from: sigData, at: 0)
            if sig != 0x02014b50 { break }  // Central Directory File Header
            
            let headerData = handle.readData(ofLength: 42)
            guard headerData.count == 42 else { break }
            
            let compressionMethod = readUInt16(from: headerData, at: 6)
            let compressedSize = readUInt32(from: headerData, at: 16)
            let uncompressedSize = readUInt32(from: headerData, at: 20)
            let nameLength = readUInt16(from: headerData, at: 24)
            let extraLength = readUInt16(from: headerData, at: 26)
            let commentLength = readUInt16(from: headerData, at: 28)
            let localHeaderOffset = readUInt32(from: headerData, at: 38)
            
            let nameData = handle.readData(ofLength: Int(nameLength))
            let path = String(data: nameData, encoding: .utf8) ?? ""
            
            // 跳过 extra 和 comment
            let currentOffset = (try? handle.offset()) ?? 0
            try? handle.seek(toOffset: currentOffset + UInt64(extraLength + commentLength))
            
            let entry = Entry(path: path, compressedSize: compressedSize, 
                            uncompressedSize: uncompressedSize, offset: localHeaderOffset,
                            compressionMethod: compressionMethod)
            
            entries.append(entry)
        }
    }
    
    func extract(_ entry: Entry, to url: URL) throws {
        guard let handle = fileHandle else { throw NSError(domain: "ZIPArchive", code: 2) }
        
        // 读取 Local File Header
        try handle.seek(toOffset: UInt64(entry.offset))
        let sigData = handle.readData(ofLength: 4)
        guard readUInt32(from: sigData, at: 0) == 0x04034b50 else {
            throw NSError(domain: "ZIPArchive", code: 3)
        }
        
        let headerData = handle.readData(ofLength: 26)
        let nameLength = readUInt16(from: headerData, at: 22)
        let extraLength = readUInt16(from: headerData, at: 24)
        
        // 跳过文件名和 extra
        let currentOffset = try handle.offset()
        try handle.seek(toOffset: currentOffset + UInt64(nameLength + extraLength))
        
        // 读取压缩数据
        let compressedData = handle.readData(ofLength: Int(entry.compressedSize))
        
        var data: Data
        if entry.compressionMethod == 0 {
            // 未压缩
            data = compressedData
        } else if entry.compressionMethod == 8 {
            // Deflate
            data = try decompress(compressedData, uncompressedSize: Int(entry.uncompressedSize))
        } else {
            throw NSError(domain: "ZIPArchive", code: 4, 
                         userInfo: [NSLocalizedDescriptionKey: "Unsupported compression method: \(entry.compressionMethod)"])
        }
        
        try data.write(to: url)
    }
    
    private func decompress(_ data: Data, uncompressedSize: Int) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }
        
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
        defer { destinationBuffer.deallocate() }
        
        let decompressedSize = data.withUnsafeBytes { sourcePtr -> Int in
            guard let baseAddress = sourcePtr.bindMemory(to: UInt8.self).baseAddress else {
                return 0
            }
            return compression_decode_buffer(destinationBuffer, uncompressedSize,
                                            baseAddress, data.count,
                                            nil, COMPRESSION_ZLIB)
        }
        
        guard decompressedSize > 0 else {
            throw NSError(domain: "ZIPArchive", code: 5, 
                         userInfo: [NSLocalizedDescriptionKey: "Decompression failed"])
        }
        
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}
