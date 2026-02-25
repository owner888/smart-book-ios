import CryptoKit
import Foundation
import UIKit

enum TwitterVideoServiceError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case userVerifyFailed
    case parseFailed
    case serviceError(status: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Twitter URL"
        case .requestFailed(let statusCode):
            return "Request failed with status: \(statusCode)"
        case .userVerifyFailed:
            return "Twitter user verify failed"
        case .parseFailed:
            return "Failed to parse twitter video info"
        case .serviceError(let status):
            return "Twitter service error: \(status ?? "unknown")"
        }
    }
}

final class TwitterVideoService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchTwitterVideo(_ value: String) async throws -> TwitterVideoModel {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TwitterVideoServiceError.invalidURL
        }

        let token = try await verifyUserAndGetToken(url: value)
        var model = try await searchTwitterVideo(url: value, token: token)

        guard model.isSuccess else {
            throw TwitterVideoServiceError.serviceError(status: model.status)
        }

        enrichModelByHTML(&model)
        return model
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
            throw TwitterVideoServiceError.parseFailed
        }
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
        guard totalBytesExpectedToWrite > 0 else { return }
        let value = Int((Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100)
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
