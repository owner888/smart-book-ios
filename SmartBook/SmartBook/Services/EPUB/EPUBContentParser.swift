// EPUBContentParser.swift - EPUB 内容解析器

import Foundation

/// EPUB 内容解析器
class EPUBContentParser {
    
    // MARK: - Manifest 和 Spine 解析
    
    /// 解析 manifest（资源清单）
    static func parseManifest(from xml: String) -> [String: String] {
        var manifest: [String: String] = [:]
        
        // 匹配 <item id="xxx" href="xxx" .../>
        let itemPattern = #"<item[^>]+id\s*=\s*["']([^"']+)["'][^>]+href\s*=\s*["']([^"']+)["']"#
        let itemPattern2 = #"<item[^>]+href\s*=\s*["']([^"']+)["'][^>]+id\s*=\s*["']([^"']+)["']"#
        
        if let regex = try? NSRegularExpression(pattern: itemPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: xml),
                   let hrefRange = Range(match.range(at: 2), in: xml) {
                    let id = String(xml[idRange])
                    let href = String(xml[hrefRange]).removingPercentEncoding ?? String(xml[hrefRange])
                    manifest[id] = href
                }
            }
        }
        
        if let regex = try? NSRegularExpression(pattern: itemPattern2, options: .caseInsensitive) {
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            for match in matches {
                if let hrefRange = Range(match.range(at: 1), in: xml),
                   let idRange = Range(match.range(at: 2), in: xml) {
                    let id = String(xml[idRange])
                    let href = String(xml[hrefRange]).removingPercentEncoding ?? String(xml[hrefRange])
                    if manifest[id] == nil {
                        manifest[id] = href
                    }
                }
            }
        }
        
        return manifest
    }
    
    /// 解析 spine（阅读顺序）
    static func parseSpine(from xml: String) -> [String] {
        var spine: [String] = []
        
        // 匹配 <itemref idref="xxx"/>
        let itemRefPattern = #"<itemref[^>]+idref\s*=\s*["']([^"']+)["']"#
        
        if let regex = try? NSRegularExpression(pattern: itemRefPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            for match in matches {
                if let range = Range(match.range(at: 1), in: xml) {
                    spine.append(String(xml[range]))
                }
            }
        }
        
        return spine
    }
    
    // MARK: - TOC 解析
    
    /// 解析 TOC（目录）
    static func parseTOC(from xml: String, manifest: [String: String], opfDir: URL) -> [String: String] {
        var tocMap: [String: String] = [:]
        
        // 查找 NCX 文件
        var ncxHref: String?
        
        // 方法1: 查找 spine 中的 toc 属性
        let tocPattern = #"<spine[^>]+toc\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: tocPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
           let range = Range(match.range(at: 1), in: xml) {
            let tocId = String(xml[range])
            ncxHref = manifest[tocId]
        }
        
        // 方法2: 查找 media-type="application/x-dtbncx+xml" 的 item
        if ncxHref == nil {
            let ncxPattern = "<item[^>]+media-type\\s*=\\s*[\"']application/x-dtbncx\\+xml[\"'][^>]+href\\s*=\\s*[\"']([^\"']+)[\"']"
            if let regex = try? NSRegularExpression(pattern: ncxPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
               let range = Range(match.range(at: 1), in: xml) {
                ncxHref = String(xml[range])
            }
        }
        
        // 解析 NCX 文件
        if let href = ncxHref {
            let ncxPath = opfDir.appendingPathComponent(href)
            if let ncxData = try? Data(contentsOf: ncxPath),
               let ncxXML = String(data: ncxData, encoding: .utf8) {
                tocMap = parseNCX(ncxXML)
            }
        }
        
        // 也尝试解析 EPUB3 的 nav 文件
        let navPattern = "<item[^>]+properties\\s*=\\s*[\"'][^\"']*nav[^\"']*[\"'][^>]+href\\s*=\\s*[\"']([^\"']+)[\"']"
        if let regex = try? NSRegularExpression(pattern: navPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
           let range = Range(match.range(at: 1), in: xml) {
            let navHref = String(xml[range])
            let navPath = opfDir.appendingPathComponent(navHref)
            if let navData = try? Data(contentsOf: navPath),
               let navHTML = String(data: navData, encoding: .utf8) {
                let navToc = parseNav(navHTML)
                for (key, value) in navToc {
                    if tocMap[key] == nil {
                        tocMap[key] = value
                    }
                }
            }
        }
        
        return tocMap
    }
    
    /// 解析 NCX 文件
    static func parseNCX(_ xml: String) -> [String: String] {
        var toc: [String: String] = [:]
        
        // 匹配 <navPoint>...</navPoint>
        let navPointPattern = "<navPoint[^>]*>.*?<navLabel>\\s*<text>([^<]*)</text>\\s*</navLabel>\\s*<content\\s+src\\s*=\\s*[\"']([^\"']+)[\"']"
        
        if let regex = try? NSRegularExpression(pattern: navPointPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            for match in matches {
                if let titleRange = Range(match.range(at: 1), in: xml),
                   let srcRange = Range(match.range(at: 2), in: xml) {
                    let title = String(xml[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    var src = String(xml[srcRange])
                    // 移除锚点
                    if let hashIndex = src.firstIndex(of: "#") {
                        src = String(src[..<hashIndex])
                    }
                    src = src.removingPercentEncoding ?? src
                    if !title.isEmpty {
                        toc[src] = title
                    }
                }
            }
        }
        
        return toc
    }
    
    /// 解析 EPUB3 nav 文件
    static func parseNav(_ html: String) -> [String: String] {
        var toc: [String: String] = [:]
        
        // 匹配 <a href="xxx">title</a>
        let linkPattern = #"<a[^>]+href\s*=\s*["']([^"']+)["'][^>]*>([^<]+)</a>"#
        
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let hrefRange = Range(match.range(at: 1), in: html),
                   let titleRange = Range(match.range(at: 2), in: html) {
                    var href = String(html[hrefRange])
                    let title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    // 移除锚点
                    if let hashIndex = href.firstIndex(of: "#") {
                        href = String(href[..<hashIndex])
                    }
                    href = href.removingPercentEncoding ?? href
                    if !title.isEmpty && !href.isEmpty {
                        toc[href] = title
                    }
                }
            }
        }
        
        return toc
    }
    
    // MARK: - HTML 文本提取
    
    /// 从 HTML 中提取纯文本
    static func extractTextFromHTML(_ html: String) -> String {
        var text = html
        
        // 移除 script 和 style 标签及其内容
        let scriptPattern = #"<script[^>]*>[\s\S]*?</script>"#
        let stylePattern = #"<style[^>]*>[\s\S]*?</style>"#
        
        if let regex = try? NSRegularExpression(pattern: scriptPattern, options: .caseInsensitive) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        if let regex = try? NSRegularExpression(pattern: stylePattern, options: .caseInsensitive) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        
        // 处理段落和换行
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</h1>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</h2>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</h3>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</h4>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
        
        // 移除所有 HTML 标签
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        
        // 解码 HTML 实体
        text = decodeHTMLEntities(text)
        
        // 清理多余空白
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        
        // 合并多个连续换行为两个
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        // 移除行首行尾空白
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        text = lines.joined(separator: "\n")
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 解码 HTML 实体
    static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&ldquo;": "\u{201C}",
            "&rdquo;": "\u{201D}",
            "&lsquo;": "\u{2018}",
            "&rsquo;": "\u{2019}",
            "&mdash;": "\u{2014}",
            "&ndash;": "\u{2013}",
            "&hellip;": "\u{2026}",
            "&copy;": "\u{00A9}",
            "&reg;": "\u{00AE}",
            "&trade;": "\u{2122}",
            "&#160;": " ",
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // 处理数字实体 &#xxx;
        let numericPattern = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            var searchRange = result.startIndex..<result.endIndex
            while let match = regex.firstMatch(in: result, range: NSRange(searchRange, in: result)),
                  let range = Range(match.range, in: result),
                  let numRange = Range(match.range(at: 1), in: result) {
                let numString = String(result[numRange])
                if let num = Int(numString), let scalar = Unicode.Scalar(num) {
                    let char = String(Character(scalar))
                    result.replaceSubrange(range, with: char)
                    searchRange = result.index(range.lowerBound, offsetBy: char.count)..<result.endIndex
                } else {
                    searchRange = range.upperBound..<result.endIndex
                }
            }
        }
        
        return result
    }
}
