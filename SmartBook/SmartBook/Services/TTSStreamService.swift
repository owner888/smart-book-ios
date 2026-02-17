// TTSStreamService.swift - 实时流式语音合成服务
// 使用 WebSocket 连接后端，实现边接收文本边播放语音

import AVFoundation
import Combine
import CryptoKit
import Foundation

class TTSStreamService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var error: String?

    // ✅ 使用统一的 WebSocketClient
    private var wsClient: WebSocketClient?
    private var audioPlayer: AudioStreamPlayer?
    private var audioEncoding: AudioEncoding = .mp3  // 默认使用 MP3
    
    // ✅ 连接状态直接从 WebSocketClient 获取
    var isConnected: Bool {
        wsClient?.isConnected ?? false
    }

    override init() {
        super.init()
        audioPlayer = AudioStreamPlayer()

        // 启动时清理旧的临时音频文件
        cleanupOldTempFiles()
    }

    deinit {
        wsClient?.disconnect()
    }

    // MARK: - 播放完成回调

    /// 设置播放完成回调
    func setOnPlaybackComplete(_ callback: @escaping () -> Void) {
        audioPlayer?.onPlaybackComplete = callback
    }

    // MARK: - WebSocket 连接

    @MainActor
    func connect(model: String = "aura-asteria-zh") async {
        // 使用 AppConfig 统一管理的 WebSocket URL
        let wsURL = AppConfig.wsTTSBaseURL

        Logger.info("TTS WebSocket URL: \(wsURL)")

        guard let url = URL(string: wsURL) else {
            self.error = "无效的 WebSocket URL"
            return
        }

        // ✅ 使用 WebSocketClient 统一管理连接
        wsClient = WebSocketClient(url: url)
        
        wsClient?.connect(
            onConnected: {
                Logger.info("TTS WebSocket 连接成功")
            },
            onDisconnected: { [weak self] error in
                if let error = error {
                    Logger.error("TTS WebSocket 断开: \(error.localizedDescription)")
                    self?.error = error.localizedDescription
                }
            },
            onMessage: { [weak self] message in
                switch message {
                case .text(let text):
                    self?.handleTextMessage(text)
                case .data(let data):
                    self?.handleAudioData(data)
                }
            }
        )
    }

    @MainActor
    func disconnect() async {
        guard isConnected else { return }

        // 发送停止消息
        try? await wsClient?.send(json: ["type": "stop"])

        // ✅ 使用 WebSocketClient 断开
        wsClient?.disconnect()
        wsClient = nil

        // 停止播放
        audioPlayer?.stop()

        Logger.info("TTS WebSocket 连接已关闭")
    }

    // MARK: - TTS 控制

    @MainActor
    func startTTS(model: String? = nil) async {
        guard isConnected else {
            Logger.error("TTS WebSocket 未连接")
            return
        }

        // 发送 start 消息
        // 不指定 model，让服务器自动选择（会选 Google TTS 支持中文）
        var startMessage: [String: Any] = [
            "type": "start",
            "provider": "auto",  // 自动选择
            "encoding": "mp3",  // Google TTS 支持 MP3
            "sample_rate": 24000,
        ]

        // 如果指定了模型，添加到消息中
        if let model = model {
            startMessage["model"] = model
        }

        await sendMessage(startMessage)

        // 准备音频播放器
        audioPlayer?.prepare()

        isPlaying = true
        Logger.info("TTS 会话已启动")
    }

    @MainActor
    func sendText(_ text: String) async {
        guard isConnected else { return }

        let textMessage: [String: Any] = [
            "type": "text",
            "text": text,
        ]

        await sendMessage(textMessage)
        Logger.debug("已发送文本: \(text)")
    }

    @MainActor
    func flush() async {
        guard isConnected else { return }

        let flushMessage: [String: Any] = ["type": "flush"]
        await sendMessage(flushMessage)
        Logger.info("已发送 flush 信号")
    }

    @MainActor
    func stopTTS() async {
        guard isPlaying else { return }

        let stopMessage: [String: Any] = ["type": "stop"]
        await sendMessage(stopMessage)

        audioPlayer?.stop()
        isPlaying = false
        Logger.info("TTS 已停止")
    }

    // MARK: - 消息处理

    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["type"] as? String
        else {
            return
        }

        Task { @MainActor in
            switch type {
            case "connected":
                Logger.info("TTS WebSocket 连接成功")

            case "started":
                Logger.info("Deepgram TTS 已启动")

            case "summary":
                // 接收文本发送汇总信息
                let textCount = json["text_count"] as? Int ?? 0
                let totalChars = json["total_chars"] as? Int ?? 0
                let provider = json["provider"] as? String ?? "unknown"

                Logger.info("📊 TTS 汇总: \(textCount)个片段, \(totalChars)个字符, 提供商: \(provider)")

            case "stopped":
                Logger.info("TTS 已停止，开始播放累积的音频")
                // TTS 结束，播放累积的音频
                self.audioPlayer?.playComplete()

            case "error":
                let errorMsg = json["message"] as? String ?? "Unknown error"
                Logger.error("TTS 错误: \(errorMsg)")
                self.error = errorMsg

            case "pong":
                // 心跳响应
                break

            default:
                Logger.info("未知消息类型: \(type)")
            }
        }
    }

    private func handleAudioData(_ data: Data) {
        // 检查是否是 JSON 消息（误发到二进制）
        if let jsonString = String(data: data, encoding: .utf8),
            jsonString.starts(with: "{")
        {
            return
        }

        // 累积音频数据（不输出日志，避免刷屏）
        audioPlayer?.receiveAudio(data)
    }

    private func sendMessage(_ message: [String: Any]) async {
        // ✅ 使用 WebSocketClient 发送消息
        do {
            try await wsClient?.send(json: message)
        } catch {
            Logger.error("发送消息失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 临时文件清理

    /// 清理旧的临时音频文件
    private func cleanupOldTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileManager = FileManager.default

        do {
            let files = try fileManager.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            // 筛选出 TTS 临时文件
            let ttsFiles = files.filter { $0.lastPathComponent.hasPrefix("tts_") }

            let now = Date()
            var cleanedCount = 0
            var cleanedSize = 0

            for file in ttsFiles {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: file.path)
                    if let creationDate = attributes[.creationDate] as? Date {
                        // 删除超过1小时的文件
                        if now.timeIntervalSince(creationDate) > 3600 {
                            let fileSize = (attributes[.size] as? Int) ?? 0
                            try fileManager.removeItem(at: file)
                            cleanedCount += 1
                            cleanedSize += fileSize
                        }
                    }
                } catch {
                    // 删除失败，可能文件不存在，继续
                    continue
                }
            }

            if cleanedCount > 0 {
                Logger.info("🧹 清理了 \(cleanedCount) 个旧的临时音频文件，释放 \(cleanedSize / 1024) KB")
            }

        } catch {
            Logger.error("清理临时文件失败: \(error)")
        }
    }

    /// 设置音频编码格式
    func setAudioEncoding(_ encoding: AudioEncoding) {
        audioEncoding = encoding
        audioPlayer?.audioEncoding = encoding
    }
}

// MARK: - 流式音频播放器

class AudioStreamPlayer: NSObject {
    private var audioPlayer: AVPlayer?
    private var audioBuffer = Data()
    private var playTimer: Timer?
    private var isSessionActive = false  // TTS 会话是否活跃
    var audioEncoding: AudioEncoding = .mp3  // 音频编码格式

    // 播放完成回调
    var onPlaybackComplete: (() -> Void)?

    override init() {
        super.init()
        setupAudioSession()
    }

    deinit {
        playTimer?.invalidate()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,  // 支持同时录音和播放
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.error("音频会话配置失败: \(error)")
        }
    }

    func prepare() {
        // 清空缓冲区
        audioBuffer = Data()
        isSessionActive = true  // 激活会话
        Logger.info("音频播放器已准备好，会话已激活")
    }

    // 接收音频数据（累积）
    func receiveAudio(_ data: Data) {
        // 只在会话活跃时才累积音频
        guard isSessionActive else {
            return
        }

        // 累积音频数据（不输出日志）
        audioBuffer.append(data)

        // 只有累积到一定大小（1KB）才启动播放定时器
        if audioBuffer.count >= 1024 {
            // 重置定时器，如果2秒没有新数据就自动播放
            DispatchQueue.main.async { [weak self] in
                self?.playTimer?.invalidate()
                self?.playTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    Logger.info("⏱️ 2秒无新数据，自动播放")
                    self?.playComplete()
                }
            }
        }
    }

    // 所有音频接收完成，开始播放
    func playComplete() {
        guard !audioBuffer.isEmpty else { return }

        // 配置音频会话以支持播放
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // 直接配置为播放和录音模式（不停用）
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )

            // 强制输出到扬声器
            try audioSession.overrideOutputAudioPort(.speaker)

            Logger.info("✅ 音频会话已配置，输出到扬声器")
        } catch {
            Logger.error("音频会话配置失败: \(error)")
        }

        // 将音频数据保存到临时文件（使用动态格式）
        let tempDir = FileManager.default.temporaryDirectory
        let fileExtension = audioEncoding.fileExtension
        let audioFile = tempDir.appendingPathComponent("tts_\(UUID().uuidString).\(fileExtension)")

        do {
            try audioBuffer.write(to: audioFile)

            // 使用 AVPlayer 播放
            let playerItem = AVPlayerItem(url: audioFile)
            audioPlayer = AVPlayer(playerItem: playerItem)

            // 设置音量
            audioPlayer?.volume = 1.0

            // 监听 playerItem 状态
            var statusObserver: NSKeyValueObservation?
            statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
                Logger.info("PlayerItem 状态: \(item.status.rawValue)")

                if item.status == .readyToPlay {
                    Logger.info("✅ 准备好播放，开始播放")
                    self?.audioPlayer?.play()
                } else if item.status == .failed {
                    if let error = item.error {
                        Logger.error("❌ PlayerItem 失败: \(error.localizedDescription)")
                    }
                }
            }

            // 监听播放完成
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                Logger.info("🎵 音频播放完成")

                statusObserver?.invalidate()

                // 删除临时文件
                try? FileManager.default.removeItem(at: audioFile)

                // 通知外部播放已完成
                self?.onPlaybackComplete?()
            }
            isSessionActive = false  // 停用会话

            // 输出音频汇总信息
            let md5 = audioBuffer.md5()
            Logger.info("🔊 音频播放汇总: \(audioBuffer.count) 字节, MD5: \(md5)")

        } catch {
            Logger.error("播放音频失败: \(error)")
        }
    }

    func stop() {
        // 立即停止播放
        audioPlayer?.pause()
        audioPlayer?.replaceCurrentItem(with: nil)  // 清空播放队列
        audioPlayer = nil

        // 清理所有状态
        audioBuffer = Data()
        isSessionActive = false

        // 停止定时器
        playTimer?.invalidate()
        playTimer = nil

        Logger.info("音频播放已立即停止")
    }

}

// MARK: - MD5 Extension

extension Data {
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
