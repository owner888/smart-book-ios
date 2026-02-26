import CryptoKit
import Foundation
import UIKit

enum TwitterVideoServiceError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case userVerifyFailed
    case parseFailed
    case serviceError(status: String?)
    case noMediaFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Twitter URL"
        case .requestFailed(let statusCode):
            return "Request failed with status: \(statusCode)"
        case .userVerifyFailed:
            return "Twitter user verify failed"
        case .parseFailed:
            return "Failed to parse video info"
        case .serviceError(let status):
            if status == "error.api.auth.jwt.missing" {
                return "Cobalt 实例需要 Bearer JWT，请更换为你自己的实例，或配置可用的认证令牌。"
            }
            if status == "error.api.auth.api-key.missing" || status == "error.api.auth.key.missing" {
                return "Cobalt 实例需要 Api-Key，请在设置中填写 Cobalt API Key。"
            }
            if status == "error.api.auth.key.not_found" {
                return "当前 Cobalt API Key 不存在或未生效，请检查设置中的 key 是否被旧值覆盖，并与服务端 keys.json 完全一致。"
            }
            if status == "error.api.auth.key.invalid" {
                return "当前 Cobalt API Key 格式无效，请使用 UUID 格式的 key。"
            }
            return "Twitter service error: \(status ?? "unknown")"
        case .noMediaFound:
            return "No downloadable media found"
        }
    }
}

final class TwitterVideoService {
    private let session: URLSession
    private let cobaltBaseURL: String
    private let youtubeQualities = ["1080", "720", "480", "360"]

    private var parserSource: String {
        UserDefaults.standard.string(forKey: AppConfig.Keys.twitterParserSource)
            ?? AppConfig.DefaultValues.twitterParserSource
    }

    private var cobaltApiKey: String {
        AppConfig.cobaltApiKey
    }

    init(
        session: URLSession = .shared,
        cobaltBaseURL: String = AppConfig.cobaltAPIURL
    ) {
        self.session = session
        self.cobaltBaseURL = cobaltBaseURL
    }

    func fetchTwitterVideo(_ value: String) async throws -> TwitterVideoModel {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TwitterVideoServiceError.invalidURL
        }

        if isYouTubeURL(value) {
            return try await searchYouTubeViaCobalt(url: value)
        }

        let source = parserSource

        if source == "x2twitter" {
            let token = try await verifyUserAndGetToken(url: value)
            var model = try await searchTwitterVideo(url: value, token: token)
            guard model.isSuccess else {
                throw TwitterVideoServiceError.serviceError(status: model.status)
            }
            enrichModelByHTML(&model)
            if model.videoList.isEmpty {
                throw TwitterVideoServiceError.noMediaFound
            }
            return model
        }

        if source == "cobalt" {
            return try await searchViaCobalt(url: value, videoQuality: "720")
        }

        do {
            let token = try await verifyUserAndGetToken(url: value)
            var model = try await searchTwitterVideo(url: value, token: token)

            guard model.isSuccess else {
                throw TwitterVideoServiceError.serviceError(status: model.status)
            }

            enrichModelByHTML(&model)
            if model.videoList.isEmpty {
                throw TwitterVideoServiceError.noMediaFound
            }
            return model
        } catch {
            return try await searchViaCobalt(url: value, videoQuality: "720")
        }
    }

    @discardableResult
    func downloadMedia(
        _ item: TwitterVideoItem,
        progress: ((Int) -> Void)? = nil
    ) async throws -> URL {
        guard let mediaURL = URL(string: item.href) else {
            throw TwitterVideoServiceError.invalidURL
        }

        let saveURL = try mediaCacheURL(for: item)
        if FileManager.default.fileExists(atPath: saveURL.path) {
            progress?(100)
            return saveURL
        }

        return try await downloadFile(from: mediaURL, to: saveURL, progress: progress)
    }
}

private extension TwitterVideoService {
    struct CobaltPickerItem: Decodable {
        let type: String?
        let url: String?
        let thumb: String?
    }

    struct CobaltResponse: Decodable {
        let status: String
        let url: String?
        let filename: String?
        let picker: [CobaltPickerItem]?
        let error: CobaltError?
    }

    struct CobaltError: Decodable {
        let code: String?
    }

    struct UserVerifyResponse: Decodable {
        let success: Bool
        let token: String?
    }

    private func verifyUserAndGetToken(url: String) async throws -> String {
        let endpoint = "https://x2twitter.com/api/userverify"
        let (data, response) = try await postForm(endpoint: endpoint, params: ["url": url])
        guard (200...299).contains(response.statusCode) else {
            throw TwitterVideoServiceError.requestFailed(statusCode: response.statusCode)
        }

        let result = try JSONDecoder().decode(UserVerifyResponse.self, from: data)
        guard result.success, let token = result.token, !token.isEmpty else {
            throw TwitterVideoServiceError.userVerifyFailed
        }
        return token
    }

    private func searchTwitterVideo(url: String, token: String) async throws -> TwitterVideoModel {
        let endpoint = "https://x2twitter.com/api/ajaxSearch"
        let (data, response) = try await postForm(
            endpoint: endpoint,
            params: [
                "q": url,
                "cftoken": token,
            ]
        )
        guard (200...299).contains(response.statusCode) else {
            throw TwitterVideoServiceError.requestFailed(statusCode: response.statusCode)
        }

        do {
            return try JSONDecoder().decode(TwitterVideoModel.self, from: data)
        } catch {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let status = object["status"] as? String
                let payload = object["data"]
                let dataString: String?
                if let html = payload as? String {
                    dataString = html
                } else if let payload {
                    dataString = String(describing: payload)
                } else {
                    dataString = nil
                }

                return TwitterVideoModel(status: status, data: dataString)
            }
            throw TwitterVideoServiceError.parseFailed
        }
    }

    private func searchViaCobalt(url: String, videoQuality: String) async throws -> TwitterVideoModel {
        let endpoint = cobaltBaseURL.hasSuffix("/") ? cobaltBaseURL : cobaltBaseURL + "/"
        guard let requestURL = URL(string: endpoint) else {
            throw TwitterVideoServiceError.invalidURL
        }

        let trimmedApiKey = cobaltApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let (data, httpResponse) = try await requestCobalt(
            requestURL: requestURL,
            url: url,
            videoQuality: videoQuality,
            apiKey: trimmedApiKey,
            includeApiKey: !trimmedApiKey.isEmpty
        )

        if !(200...299).contains(httpResponse.statusCode) {
            if let parsed = try? JSONDecoder().decode(CobaltResponse.self, from: data) {
                throw TwitterVideoServiceError.serviceError(
                    status: parsed.error?.code ?? "cobalt_http_\(httpResponse.statusCode)"
                )
            }
            throw TwitterVideoServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let parsed = try JSONDecoder().decode(CobaltResponse.self, from: data)
        var model = TwitterVideoModel(status: "ok", data: nil)

        switch parsed.status {
        case "redirect", "tunnel":
            if let mediaURL = parsed.url {
                let title = parsed.filename ?? "video"
                let normalizedMediaURL = normalizeCobaltMediaURL(mediaURL)
                model.videoList = [TwitterVideoItem(href: normalizedMediaURL, title: title)]
                model.title = parsed.filename
                return model
            }
            throw TwitterVideoServiceError.noMediaFound

        case "picker":
            let items = parsed.picker ?? []
            let preferredThumb = items.first(where: { ($0.type ?? "") == "video" })?.thumb
                ?? items.first?.thumb
            if let preferredThumb {
                model.videoCover = normalizeCobaltMediaURL(preferredThumb)
            }
            model.videoList = items.compactMap { entry in
                guard let mediaURL = entry.url, !mediaURL.isEmpty else { return nil }
                let type = entry.type ?? "media"
                return TwitterVideoItem(href: normalizeCobaltMediaURL(mediaURL), title: type)
            }

            if model.videoList.isEmpty {
                throw TwitterVideoServiceError.noMediaFound
            }
            return model

        default:
            throw TwitterVideoServiceError.serviceError(status: parsed.error?.code ?? parsed.status)
        }
    }

    private func searchYouTubeViaCobalt(url: String) async throws -> TwitterVideoModel {
        var mergedModel = TwitterVideoModel(status: "ok", data: nil)
        var options: [TwitterVideoItem] = []
        var seenHrefs = Set<String>()

        for quality in youtubeQualities {
            do {
                let model = try await searchViaCobalt(url: url, videoQuality: quality)
                if mergedModel.title == nil {
                    mergedModel.title = model.title
                }
                if mergedModel.videoCover == nil {
                    mergedModel.videoCover = model.videoCover
                }

                for item in model.videoList {
                    guard !seenHrefs.contains(item.href) else { continue }
                    seenHrefs.insert(item.href)
                    let optionTitle = "\(quality)p - \(item.title)"
                    options.append(TwitterVideoItem(href: item.href, title: optionTitle))
                }
            } catch {
                continue
            }
        }

        guard !options.isEmpty else {
            throw TwitterVideoServiceError.noMediaFound
        }

        mergedModel.videoList = options
        return mergedModel
    }

    private func normalizeCobaltMediaURL(_ rawURL: String) -> String {
        guard
            let mediaURL = URL(string: rawURL),
            let baseURL = URL(string: cobaltBaseURL),
            let mediaHost = mediaURL.host,
            let baseHost = baseURL.host
        else {
            return rawURL
        }

        let lowerMediaHost = mediaHost.lowercased()
        let isLoopback = lowerMediaHost == "127.0.0.1" || lowerMediaHost == "localhost"
        guard isLoopback else {
            return rawURL
        }

        var components = URLComponents(url: mediaURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme
        components?.host = baseHost
        components?.port = baseURL.port

        return components?.url?.absoluteString ?? rawURL
    }

    private func requestCobalt(
        requestURL: URL,
        url: String,
        videoQuality: String,
        apiKey: String,
        includeApiKey: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if includeApiKey {
            request.setValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "url": url,
                "videoQuality": videoQuality,
                "downloadMode": "auto",
            ]
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwitterVideoServiceError.parseFailed
        }
        return (data, httpResponse)
    }

    private func isYouTubeURL(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("youtube.com/") || lower.contains("youtu.be/")
    }

    private func postForm(endpoint: String, params: [String: String]) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: endpoint) else {
            throw TwitterVideoServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("https://x2twitter.com/zh-cn", forHTTPHeaderField: "referer")
        request.setValue("https://x2twitter.com", forHTTPHeaderField: "origin")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "x-requested-with")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
            forHTTPHeaderField: "user-agent"
        )

        let formString = params
            .map { key, value in
                "\(key.urlQueryEscaped())=\(value.urlQueryEscaped())"
            }
            .joined(separator: "&")
        request.httpBody = formString.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwitterVideoServiceError.parseFailed
        }
        return (data, httpResponse)
    }

    private func enrichModelByHTML(_ model: inout TwitterVideoModel) {
        guard let html = model.data, !html.isEmpty else { return }

        if let cover = firstMatch(in: html, pattern: "<img[^>]*src=[\\\"']([^\\\"']+)[\\\"']") {
            model.videoCover = cover
        }

        if let title = firstMatch(in: html, pattern: "<h3[^>]*>(.*?)</h3>") {
            model.title = title.removingHTMLTags().htmlDecoded().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let pBlocks = matches(in: html, pattern: "<p[^>]*>(.*?)</p>")
        for pBlock in pBlocks {
            if let href = firstMatch(in: pBlock, pattern: "<a[^>]*href=[\\\"']([^\\\"']+)[\\\"']") {
                let text = pBlock.removingHTMLTags().htmlDecoded().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty, !text.lowercased().contains("mp3") {
                    model.videoList.append(TwitterVideoItem(href: href, title: text))
                } else if !text.isEmpty {
                    model.videoDuration = text
                }
            } else {
                let text = pBlock.removingHTMLTags().htmlDecoded().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    model.videoDuration = text
                }
            }
        }
    }

    private func mediaCacheURL(for item: TwitterVideoItem) throws -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let mediaDir = caches.appendingPathComponent("TwitterVideoCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: mediaDir.path) {
            try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        }

        let ext: String
        if item.isVideo {
            ext = "mp4"
        } else if item.isAudio {
            ext = "mp3"
        } else {
            ext = "jpg"
        }

        let fileName = "\(item.href.md5Hex()).\(ext)"
        return mediaDir.appendingPathComponent(fileName)
    }

    private func downloadFile(from remoteURL: URL, to localURL: URL, progress: ((Int) -> Void)?) async throws -> URL {
        let delegate = DownloadDelegate(destinationURL: localURL, progress: progress)
        let downloadSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        let downloadedURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            delegate.continuation = continuation
            let task = downloadSession.downloadTask(with: remoteURL)
            task.resume()
        }

        downloadSession.finishTasksAndInvalidate()
        progress?(100)
        return downloadedURL
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    var continuation: CheckedContinuation<URL, Error>?

    private let destinationURL: URL
    private let progress: ((Int) -> Void)?
    private var didResume = false
    private var didReportIndeterminate = false

    init(destinationURL: URL, progress: ((Int) -> Void)?) {
        self.destinationURL = destinationURL
        self.progress = progress
    }

    private func resumeOnce(_ result: Result<URL, Error>) {
        guard !didResume else { return }
        didResume = true

        switch result {
        case .success(let url):
            continuation?.resume(returning: url)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }

        continuation = nil
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        var expectedBytes = totalBytesExpectedToWrite

        if expectedBytes <= 0,
           let response = downloadTask.response as? HTTPURLResponse,
           let estimated = response.value(forHTTPHeaderField: "Estimated-Content-Length"),
           let parsed = Int64(estimated),
           parsed > 0 {
            expectedBytes = parsed
        }

        guard expectedBytes > 0 else {
            if totalBytesWritten > 0, !didReportIndeterminate {
                didReportIndeterminate = true
                DispatchQueue.main.async {
                    self.progress?(-1)
                }
            }
            return
        }

        let value = Int((Double(totalBytesWritten) / Double(expectedBytes)) * 100)
        DispatchQueue.main.async {
            self.progress?(max(0, min(100, value)))
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            resumeOnce(.success(destinationURL))
        } catch {
            resumeOnce(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            resumeOnce(.failure(error))
        }
    }
}

private extension String {
    func urlQueryEscaped() -> String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(.init(charactersIn: "+&="))) ?? self
    }

    func md5Hex() -> String {
        let digest = Insecure.MD5.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func removingHTMLTags() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    func htmlDecoded() -> String {
        guard let data = data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
        return attributed?.string ?? self
    }
}

private func firstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    else { return nil }
    let nsText = text as NSString
    let range = NSRange(location: 0, length: nsText.length)
    guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
        return nil
    }
    return nsText.substring(with: match.range(at: 1))
}

private func matches(in text: String, pattern: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    else { return [] }
    let nsText = text as NSString
    let range = NSRange(location: 0, length: nsText.length)
    let results = regex.matches(in: text, options: [], range: range)
    return results.compactMap { match in
        guard match.numberOfRanges > 1 else { return nil }
        return nsText.substring(with: match.range(at: 1))
    }
}
