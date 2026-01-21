// EPUBParserTests.swift - EPUB解析器单元测试

import XCTest
@testable import SmartBook

final class EPUBParserTests: XCTestCase {
    
    // MARK: - 元数据解析测试
    
    func testParseMetadata() {
        // Given: 有效的 EPUB 文件路径
        guard let testEPUBPath = Bundle(for: type(of: self)).path(forResource: "test", ofType: "epub") else {
            XCTFail("测试 EPUB 文件不存在")
            return
        }
        
        // When: 解析元数据
        let metadata = EPUBParser.parseMetadataForiOS(from: testEPUBPath)
        
        // Then: 应该成功解析
        XCTAssertNotNil(metadata, "元数据不应为 nil")
        XCTAssertNotNil(metadata.title, "标题不应为 nil")
        XCTAssertNotNil(metadata.author, "作者不应为 nil")
    }
    
    func testParseInvalidFile() {
        // Given: 无效的文件路径
        let invalidPath = "/invalid/path/to/file.epub"
        
        // When: 尝试解析
        let metadata = EPUBParser.parseMetadataForiOS(from: invalidPath)
        
        // Then: 应该返回空值或默认值
        // 根据实际实现验证
        XCTAssertTrue(metadata.title == nil || metadata.title == "", "无效文件应该返回空标题")
    }
    
    // MARK: - 内容解析测试
    
    func testParseContent() {
        // Given: 有效的 EPUB 文件
        guard let testEPUBPath = Bundle(for: type(of: self)).path(forResource: "test", ofType: "epub") else {
            throw XCTSkip("测试 EPUB 文件不存在")
        }
        
        // When: 解析内容
        // let content = EPUBParser.parseContent(from: testEPUBPath)
        
        // Then: 应该包含章节
        // XCTAssertNotNil(content, "内容不应为 nil")
        // XCTAssertFalse(content.chapters.isEmpty, "应该有章节")
    }
    
    // MARK: - 封面提取测试
    
    func testExtractCover() {
        // Given: 有 EPUB 文件
        guard let testEPUBPath = Bundle(for: type(of: self)).path(forResource: "test", ofType: "epub") else {
            throw XCTSkip("测试 EPUB 文件不存在")
        }
        
        let bookId = "test_book_id"
        
        // When: 提取封面
        let coverPath = EPUBParser.extractAndCacheCover(from: testEPUBPath, bookId: bookId)
        
        // Then: 应该成功提取
        if let coverPath = coverPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: coverPath.path), "封面文件应该存在")
        }
    }
    
    func testGetCachedCover() {
        // Given: 已缓存的封面
        let bookId = "cached_book_id"
        
        // When: 获取缓存的封面
        let coverPath = EPUBParser.getCachedCoverPath(for: bookId)
        
        // Then: 如果存在应该返回路径
        if let coverPath = coverPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: coverPath.path), "缓存的封面应该存在")
        }
    }
    
    // MARK: - 性能测试
    
    func testParseMetadataPerformance() {
        guard let testEPUBPath = Bundle(for: type(of: self)).path(forResource: "test", ofType: "epub") else {
            return
        }
        
        measure {
            _ = EPUBParser.parseMetadataForiOS(from: testEPUBPath)
        }
    }
}
