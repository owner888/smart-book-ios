// TTSCoordinatorService.swift - TTS 协调服务
// 统一管理多个 TTS 提供商，使用策略模式

import Foundation

/// TTS 协调服务
/// 负责在不同 TTS 提供商之间切换和协调
class TTSCoordinatorService {

    // MARK: - 依赖服务

    private let nativeTTS: TTSService
    private let streamTTS: TTSStreamService

    // MARK: - 配置

    private var provider: String

    // MARK: - 初始化

    init(nativeTTS: TTSService, streamTTS: TTSStreamService, provider: String) {
        self.nativeTTS = nativeTTS
        self.streamTTS = streamTTS
        self.provider = provider

        Logger.info("🎵 TTS 协调服务已初始化，提供商: \(provider)")
    }

    // MARK: - 公共方法

    /// 更新 TTS 提供商
    func updateProvider(_ newProvider: String) {
        provider = newProvider
        Logger.info("🔄 TTS 提供商切换为: \(provider)")
    }

    /// 播放文本（根据提供商自动选择）
    func speak(_ text: String) async {
        Logger.info("🔊 TTS Provider: \(provider)")

        switch provider {
        case "native":
            await speakWithNative(text)

        case "google":
            await speakWithGoogle()

        default:
            Logger.warning("⚠️ 未知的 TTS provider: \(provider)")
            // 降级到原生TTS
            await speakWithNative(text)
        }
    }

    /// 停止所有 TTS 播放
    func stopAll() async {
        await streamTTS.stopTTS()
        nativeTTS.stop()
        Logger.info("⏹️ 已停止所有 TTS 播放")
    }

    /// 发送流式文本（仅 Google TTS）
    func sendStreamingText(_ text: String) async {
        guard provider == "google" else { return }
        await streamTTS.sendText(text)
    }

    /// 准备流式 TTS（仅 Google TTS）
    func prepareStreaming() async {
        guard provider == "google" else { return }

        // 连接 WebSocket
        if !streamTTS.isConnected {
            await streamTTS.connect()
        }

        // 启动 TTS 会话
        await streamTTS.startTTS()

        // 等待握手完成
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5秒

        Logger.info("🔊 Google TTS 已就绪")
    }

    // MARK: - 私有方法

    /// 使用 iOS 原生语音播放
    private func speakWithNative(_ text: String) async {
        await nativeTTS.speak(text)
        Logger.info("🔊 使用 iOS 原生语音朗读")
    }

    /// 使用 Google TTS 播放（WebSocket 流式）
    private func speakWithGoogle() async {
        // Google TTS 已通过 WebSocket 接收音频
        // 发送 flush 触发播放
        await streamTTS.flush()
        Logger.info("🔊 Google TTS flush 已发送，等待播放")
    }
}
