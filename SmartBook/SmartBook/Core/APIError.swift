// APIError.swift - API 错误定义

import Foundation

// MARK: - API 错误
enum APIError: LocalizedError {
    case serverError
    case networkError
    case timeout
    case unauthorized
    case notFound
    case invalidRequest
    case parseError
    case unknown
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .serverError:
            return L("error.api.serverError")
        case .networkError:
            return L("error.api.networkError")
        case .timeout:
            return L("error.api.timeout")
        case .unauthorized:
            return L("error.api.unauthorized")
        case .notFound:
            return L("error.api.notFound")
        case .invalidRequest:
            return L("error.api.invalidRequest")
        case .parseError:
            return L("error.api.parseError")
        case .unknown:
            return L("error.api.unknown")
        case .custom(let message):
            return message
        }
    }

    /// 从 HTTP 状态码创建错误
    static func from(statusCode: Int) -> APIError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 404:
            return .notFound
        case 400:
            return .invalidRequest
        case 408:
            return .timeout
        case 500...599:
            return .serverError
        default:
            return .unknown
        }
    }
}

// MARK: - 书籍错误
enum BookError: LocalizedError {
    case notFound
    case invalidFormat
    case corrupted
    case uploadFailed
    case deleteFailed
    case cannotDeleteBundled

    var errorDescription: String? {
        switch self {
        case .notFound:
            return L("error.book.notFound")
        case .invalidFormat:
            return L("error.book.invalidFormat")
        case .corrupted:
            return L("error.book.corrupted")
        case .uploadFailed:
            return L("error.book.uploadFailed")
        case .deleteFailed:
            return L("error.book.deleteFailed")
        case .cannotDeleteBundled:
            return L("error.book.cannotDeleteBundled")
        }
    }
}

// MARK: - 聊天错误
enum ChatError: LocalizedError {
    case sendFailed
    case noBook
    case emptyMessage
    case streamError

    var errorDescription: String? {
        switch self {
        case .sendFailed:
            return L("error.chat.sendFailed")
        case .noBook:
            return L("error.chat.noBook")
        case .emptyMessage:
            return L("error.chat.emptyMessage")
        case .streamError:
            return L("error.chat.streamError")
        }
    }
}

// MARK: - 媒体错误
enum MediaError: LocalizedError {
    case accessDenied
    case invalidImage
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return L("error.media.accessDenied")
        case .invalidImage:
            return L("error.media.invalidImage")
        case .tooLarge:
            return L("error.media.tooLarge")
        }
    }
}

// MARK: - ASR 错误
enum ASRError: LocalizedError {
    case microphoneAccessDenied
    case audioSessionFailed
    case recordingFailed
    case recognitionFailed
    case noAudioData
    case invalidAudioFormat

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return L("error.asr.microphoneAccessDenied")
        case .audioSessionFailed:
            return L("error.asr.audioSessionFailed")
        case .recordingFailed:
            return L("error.asr.recordingFailed")
        case .recognitionFailed:
            return L("error.asr.recognitionFailed")
        case .noAudioData:
            return L("error.asr.noAudioData")
        case .invalidAudioFormat:
            return L("error.asr.invalidAudioFormat")
        }
    }
}

// MARK: - 搜索结果模型
struct SearchResult: Codable, Identifiable {
    let content: String
    let chapterTitle: String?
    let chapterIndex: Int
    let score: Double

    // Identifiable conformance
    var id: String { "\(chapterIndex)-\(score)" }

    enum CodingKeys: String, CodingKey {
        case content
        case chapterTitle = "chapter_title"
        case chapterIndex = "chapter_index"
        case score
    }
}

struct SearchResponse: Codable {
    let results: [SearchResult]?
    let error: String?
}
