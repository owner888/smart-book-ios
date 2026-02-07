// AudioEncoding.swift - 音频编码格式定义

import Foundation

/// 音频编码格式
enum AudioEncoding: String {
    case mp3 = "mp3"
    case pcm = "pcm"
    case opus = "opus"
    case mulaw = "mulaw"

    /// 文件扩展名
    var fileExtension: String {
        switch self {
        case .mp3: return "mp3"
        case .pcm: return "pcm"
        case .opus: return "opus"
        case .mulaw: return "wav"
        }
    }

    /// MIME 类型
    var mimeType: String {
        switch self {
        case .mp3: return "audio/mpeg"
        case .pcm: return "audio/pcm"
        case .opus: return "audio/opus"
        case .mulaw: return "audio/wav"
        }
    }
}
