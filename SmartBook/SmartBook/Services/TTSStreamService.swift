// TTSStreamService.swift - 实时流式语音合成服务
// 使用 WebSocket 连接后端，实现边接收文本边播放语音

import Foundation
import AVFoundation
import Combine

class TTSStreamService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var isConnected = false
    @Published var error: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioPlayer: AudioStreamPlayer?
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer? 
    private var shouldAutoReconnect = true
    private var reconnectAttempts = 0
    
    override init() {
        super.init()
        audioPlayer = AudioStreamPlayer()
    }
    
    deinit {
        heartbeatTimer?.invalidate()
        reconnectTimer?.invalidate()
        shouldAutoReconnect = false
    }
    
    // MARK: - 播放完成回调
    
    /// 设置播放完成回调
    func setOnPlaybackComplete(_ callback: @escaping () -> Void) {
        audioPlayer?.onPlaybackComplete = callback
    }
    
    // MARK: - WebSocket 连接
    
    @MainActor
    func connect(model: String = "aura-asteria-zh") async {
        // 构建 WebSocket URL
        var wsURL = AppConfig.apiBaseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        
        if let urlComponents = URLComponents(string: wsURL) {
            var components = urlComponents
            components.path = ""
            components.port = 9524  // TTS WebSocket 端口
            wsURL = components.string ?? wsURL
        }
        
        Logger.info("TTS WebSocket URL: \(wsURL)")
        
        guard let url = URL(string: wsURL) else {
            self.error = "无效的 WebSocket URL"
            return
        }
        
        // 创建 WebSocket 连接
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        
        // 开始接收消息
        receiveMessage()
        
        // 启动心跳
        startHeartbeat()
        
        Logger.info("TTS WebSocket 连接成功，心跳已启动")
    }
    
    @MainActor
    func disconnect() async {
        guard isConnected else { return }
        
        let stopMessage: [String: Any] = ["type": "stop"]
        await sendMessage(stopMessage)
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        
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
            "sample_rate": 24000
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
            "text": text
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
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleTextMessage(text)
                case .data(let audioData):
                    // 接收到音频数据
                    self.handleAudioData(audioData)
                @unknown default:
                    break
                }
                
                // 继续接收
                self.receiveMessage()
                
            case .failure(let error):
                Logger.error("TTS WebSocket Error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.error = error.localizedDescription
                    self.isConnected = false
                    self.startAutoReconnect()
                }
            }
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
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
            jsonString.starts(with: "{") {
            return
        }
        
        // 累积音频数据（不输出日志，避免刷屏）
        audioPlayer?.receiveAudio(data)
    }
    
    private func sendMessage(_ message: [String: Any]) async {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        
        do {
            try await webSocketTask?.send(message)
        } catch {
            Logger.error("发送消息失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 心跳
    
    func startHeartbeat() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            
            Task {
                await self.sendMessage(["type": "ping"])
            }
        }
    }
    
    // MARK: - 断线重连
    
    @MainActor
    private func startAutoReconnect() {
        guard shouldAutoReconnect else { return }
        
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 2.0, 30.0)
        
        Logger.info("🔄 TTS 将在 \(delay) 秒后重连（第 \(reconnectAttempts) 次）")
        
        reconnectTimer?.invalidate()
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                Logger.info("🔄 TTS 尝试重新连接...")
                await self.connect()
                
                if self.isConnected {
                    self.reconnectAttempts = 0
                    Logger.info("✅ TTS 重连成功")
                }
            }
        }
    }
}

// MARK: - 流式音频播放器

class AudioStreamPlayer: NSObject {
    private var audioPlayer: AVPlayer?
    private var audioBuffer = Data()
    private var playTimer: Timer?
    private var isSessionActive = false  // TTS 会话是否活跃
    
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
        
        // 将音频数据保存到临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let audioFile = tempDir.appendingPathComponent("tts_\(UUID().uuidString).mp3")
        
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

import CryptoKit

extension Data {
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
