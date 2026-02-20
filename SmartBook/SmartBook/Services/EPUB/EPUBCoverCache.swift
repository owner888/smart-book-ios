// EPUBCoverCache.swift - EPUB 封面缓存管理

import Foundation
import UIKit

/// EPUB 封面缓存管理器
class EPUBCoverCache {

    /// 提取并保存封面图片到缓存目录
    static func extractAndCacheCover(from epubPath: String, bookId: String) -> URL? {
        let metadata = EPUBParser.parseMetadataForiOS(from: epubPath)

        guard let coverImage = metadata.coverImage,
            let imageData = coverImage.jpegData(compressionQuality: 0.8)
        else {
            return nil
        }

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let coversDir = cacheDir.appendingPathComponent("BookCovers")

        try? FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)

        let safeBookId = sanitizeBookId(bookId)
        let coverURL = coversDir.appendingPathComponent("\(safeBookId).jpg")

        do {
            try imageData.write(to: coverURL)
            return coverURL
        } catch {
            Logger.error("Failed to save cover image: \(error)")
            return nil
        }
    }

    /// 获取缓存的封面图片路径
    static func getCachedCoverPath(for bookId: String) -> URL? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let safeBookId = sanitizeBookId(bookId)
        let coverURL = cacheDir.appendingPathComponent("BookCovers/\(safeBookId).jpg")

        if FileManager.default.fileExists(atPath: coverURL.path) {
            return coverURL
        }
        return nil
    }

    /// 清理特定书籍的封面缓存
    static func clearCachedCover(for bookId: String) {
        guard let coverURL = getCachedCoverPath(for: bookId) else { return }
        try? FileManager.default.removeItem(at: coverURL)
    }

    /// 清理所有封面缓存
    static func clearAllCachedCovers() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let coversDir = cacheDir.appendingPathComponent("BookCovers")
        try? FileManager.default.removeItem(at: coversDir)
    }

    /// 获取缓存目录大小
    static func getCacheSize() -> Int64 {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let coversDir = cacheDir.appendingPathComponent("BookCovers")

        guard let enumerator = FileManager.default.enumerator(at: coversDir, includingPropertiesForKeys: [.fileSizeKey])
        else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                let fileSize = resourceValues.fileSize
            else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    // MARK: - Private Helper

    /// 清理 bookId 使其适合作为文件名
    private static func sanitizeBookId(_ bookId: String) -> String {
        return
            bookId
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "*", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
            .replacingOccurrences(of: "|", with: "_")
    }
}
