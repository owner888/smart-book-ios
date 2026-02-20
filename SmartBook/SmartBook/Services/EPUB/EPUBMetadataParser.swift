// EPUBMetadataParser.swift - EPUB 元数据解析器

import Foundation
import UIKit

/// EPUB 元数据解析器
class EPUBMetadataParser {

    /// 解析 container.xml 获取 OPF 文件路径
    static func parseContainerXML(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
            let xmlString = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        let pattern = #"full-path\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
            let range = Range(match.range(at: 1), in: xmlString)
        else {
            return nil
        }

        return String(xmlString[range])
    }

    /// 解析 OPF 文件获取元数据
    static func parseOPFFile(at url: URL, opfDir: URL) -> EPUBMetadata {
        var metadata = EPUBMetadata()

        guard let data = try? Data(contentsOf: url),
            let xmlString = String(data: data, encoding: .utf8)
        else {
            return metadata
        }

        metadata.title =
            extractXMLElement(from: xmlString, tag: "dc:title")
            ?? extractXMLElement(from: xmlString, tag: "title")

        metadata.author =
            extractXMLElement(from: xmlString, tag: "dc:creator")
            ?? extractXMLElement(from: xmlString, tag: "creator")

        metadata.publisher =
            extractXMLElement(from: xmlString, tag: "dc:publisher")
            ?? extractXMLElement(from: xmlString, tag: "publisher")

        metadata.language =
            extractXMLElement(from: xmlString, tag: "dc:language")
            ?? extractXMLElement(from: xmlString, tag: "language")

        metadata.description =
            extractXMLElement(from: xmlString, tag: "dc:description")
            ?? extractXMLElement(from: xmlString, tag: "description")

        if let coverPath = extractCoverImagePath(from: xmlString, opfDir: opfDir) {
            if let imageData = try? Data(contentsOf: URL(fileURLWithPath: coverPath)) {
                metadata.coverImage = UIImage(data: imageData)
            }
        }

        return metadata
    }

    /// 从 XML 中提取指定标签的内容
    static func extractXMLElement(from xml: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>([^<]*)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
            let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
            let range = Range(match.range(at: 1), in: xml)
        else {
            return nil
        }

        let content = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }

    /// 提取封面图片路径
    static func extractCoverImagePath(from xml: String, opfDir: URL) -> String? {
        var coverId: String?

        // 方法1: 查找 <meta name="cover" content="xxx"/>
        let metaPattern = "<meta\\s+name\\s*=\\s*[\"']cover[\"'][^>]*content\\s*=\\s*[\"']([^\"']+)[\"']"
        if let regex = try? NSRegularExpression(pattern: metaPattern, options: .caseInsensitive),
            let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
            let range = Range(match.range(at: 1), in: xml)
        {
            coverId = String(xml[range])
        }

        // 方法2: 查找 properties="cover-image" 的 item
        if coverId == nil {
            let coverItemPattern =
                "<item[^>]+properties\\s*=\\s*[\"'][^\"']*cover-image[^\"']*[\"'][^>]*href\\s*=\\s*[\"']([^\"']+)[\"']"
            if let regex = try? NSRegularExpression(pattern: coverItemPattern, options: .caseInsensitive),
                let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
                let range = Range(match.range(at: 1), in: xml)
            {
                let href = String(xml[range])
                return opfDir.appendingPathComponent(href).path
            }

            let coverItemPattern2 =
                "<item[^>]+href\\s*=\\s*[\"']([^\"']+)[\"'][^>]*properties\\s*=\\s*[\"'][^\"']*cover-image[^\"']*[\"']"
            if let regex = try? NSRegularExpression(pattern: coverItemPattern2, options: .caseInsensitive),
                let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
                let range = Range(match.range(at: 1), in: xml)
            {
                let href = String(xml[range])
                return opfDir.appendingPathComponent(href).path
            }
        }

        // 根据 coverId 查找 item
        if let id = coverId {
            let itemPattern = "<item[^>]+id\\s*=\\s*[\"']\(id)[\"'][^>]*href\\s*=\\s*[\"']([^\"']+)[\"']"
            if let regex = try? NSRegularExpression(pattern: itemPattern, options: .caseInsensitive),
                let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
                let range = Range(match.range(at: 1), in: xml)
            {
                let href = String(xml[range])
                return opfDir.appendingPathComponent(href).path
            }

            let itemPattern2 = "<item[^>]+href\\s*=\\s*[\"']([^\"']+)[\"'][^>]*id\\s*=\\s*[\"']\(id)[\"']"
            if let regex = try? NSRegularExpression(pattern: itemPattern2, options: .caseInsensitive),
                let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
                let range = Range(match.range(at: 1), in: xml)
            {
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
                    if href.lowercased().contains("cover")
                        && (href.hasSuffix(".jpg") || href.hasSuffix(".jpeg") || href.hasSuffix(".png"))
                    {
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
}
