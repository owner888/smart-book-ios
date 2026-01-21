// ZIPArchive.swift - ZIP 归档读取器（纯 Swift 实现）

import Foundation
import Compression

/// ZIP Archive 读取器
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
            Logger.error("Failed to open archive: \(error)")
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
    
    // MARK: - 解析 ZIP 文件结构
    
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
            throw NSError(domain: "ZIPArchive", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP file"])
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
            
            let entry = Entry(
                path: path, 
                compressedSize: compressedSize, 
                uncompressedSize: uncompressedSize, 
                offset: localHeaderOffset,
                compressionMethod: compressionMethod
            )
            
            entries.append(entry)
        }
    }
    
    // MARK: - 解压文件
    
    func extract(_ entry: Entry, to url: URL) throws {
        guard let handle = fileHandle else { 
            throw NSError(domain: "ZIPArchive", code: 2, 
                         userInfo: [NSLocalizedDescriptionKey: "File handle is nil"])
        }
        
        // 读取 Local File Header
        try handle.seek(toOffset: UInt64(entry.offset))
        let sigData = handle.readData(ofLength: 4)
        guard readUInt32(from: sigData, at: 0) == 0x04034b50 else {
            throw NSError(domain: "ZIPArchive", code: 3, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid local file header"])
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
    
    // MARK: - 解压缩
    
    private func decompress(_ data: Data, uncompressedSize: Int) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }
        
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
        defer { destinationBuffer.deallocate() }
        
        let decompressedSize = data.withUnsafeBytes { sourcePtr -> Int in
            guard let baseAddress = sourcePtr.bindMemory(to: UInt8.self).baseAddress else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer, uncompressedSize,
                baseAddress, data.count,
                nil, COMPRESSION_ZLIB
            )
        }
        
        guard decompressedSize > 0 else {
            throw NSError(domain: "ZIPArchive", code: 5, 
                         userInfo: [NSLocalizedDescriptionKey: "Decompression failed"])
        }
        
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}
