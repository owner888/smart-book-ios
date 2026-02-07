// MediaProcessingService.swift - 媒体处理服务
// 负责处理图片、文档等媒体文件的转换和格式化

import UIKit

/// 媒体处理服务
class MediaProcessingService {
    
    // MARK: - 处理结果
    
    /// 处理后的媒体数据
    struct ProcessedMedia {
        let description: String      // 用于显示的描述文本
        let images: [[String: Any]]? // 用于API请求的图片数据
    }
    
    // MARK: - 公共方法
    
    /// 处理媒体项列表
    /// - Parameter items: 媒体项数组
    /// - Returns: 处理后的媒体数据（描述文本 + 图片数据）
    func processMediaItems(_ items: [MediaItem]) -> ProcessedMedia {
        guard !items.isEmpty else {
            return ProcessedMedia(description: "", images: nil)
        }
        
        var mediaDescription = ""
        var images: [[String: Any]] = []
        
        Logger.info("📎 处理 \(items.count) 个媒体项")
        
        for (index, item) in items.enumerated() {
            switch item.type {
            case .image(let image):
                if let (desc, data) = processImage(image, index: index + 1) {
                    mediaDescription += desc
                    images.append(data)
                }
                
            case .document(let url):
                if let desc = processDocument(url, index: index + 1) {
                    mediaDescription += desc
                }
            }
        }
        
        return ProcessedMedia(
            description: mediaDescription,
            images: images.isEmpty ? nil : images
        )
    }
    
    // MARK: - 私有方法
    
    /// 处理单个图片
    /// - Parameters:
    ///   - image: UIImage 对象
    ///   - index: 图片序号
    /// - Returns: (描述文本, base64数据)
    private func processImage(_ image: UIImage, index: Int) -> (String, [String: Any])? {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            Logger.warning("⚠️ 图片 \(index) 转换失败")
            return nil
        }
        
        let sizeKB = Double(jpegData.count) / 1024.0
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        
        let description = "\n[图片 \(index): \(width)x\(height), \(String(format: "%.1f", sizeKB))KB]"
        
        Logger.info("📸 图片 \(index): \(width)x\(height), \(String(format: "%.1f", sizeKB))KB")
        
        let imageData: [String: Any] = [
            "data": jpegData.base64EncodedString(),
            "mime_type": "image/jpeg"
        ]
        
        return (description, imageData)
    }
    
    /// 处理单个文档
    /// - Parameters:
    ///   - url: 文档 URL
    ///   - index: 文档序号
    /// - Returns: 描述文本
    private func processDocument(_ url: URL, index: Int) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            Logger.warning("⚠️ 文档 \(index) 读取失败: \(url.lastPathComponent)")
            return nil
        }
        
        let preview = String(content.prefix(100))
        let charCount = content.count
        let filename = url.lastPathComponent
        
        Logger.info("📄 文档 \(index): \(filename), \(charCount) 字符")
        
        return "\n[文档 \(index): \(filename), \(charCount) 字符]\n预览: \(preview)..."
    }
}
