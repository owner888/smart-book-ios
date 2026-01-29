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
            components.port = 8084  // TTS WebSocket 端口
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
    func startTTS(model: String = "aura-asteria-zh") async {
        guard isConnected else {
            Logger.error("TTS WebSocket 未连接")
            return
        }
        
        // 发送 start 消息
        // WebSocket 流式只支持 linear16/mulaw/alaw（不支持 MP3）
        let startMessage: [String: Any] = [
            "type": "start",
            "model": model,
            "encoding": "linear16",
            "sample_rate": 24000
        ]
        
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
                Logger.error("TTS WebSocket 错误: \(error.localizedDescription)")
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
                
            case "stopped":
                Logger.info("Deepgram TTS 已停止")
                self.isPlaying = false
                self.audioPlayer?.stop()
                
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
        // 播放音频数据
        audioPlayer?.playAudio(data)
        Logger.debug("收到音频数据: \(data.count) 字节")
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

class AudioStreamPlayer {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?
    
    init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else {
            return
        }
        
        // 设置音频格式（MP3 解码后的 PCM）
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 24000,
            channels: 1,
            interleaved: false
        )
        
        // 连接节点
        engine.attach(player)
        if let format = audioFormat {
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
    }
    
    func prepare() {
        guard let engine = audioEngine else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            playerNode?.play()
            Logger.info("音频播放器已准备好")
        } catch {
            Logger.error("音频播放器启动失败: \(error)")
        }
    }
    
    func playAudio(_ data: Data) {
        // 解码 MP3 数据并播放
        // 注意：需要先解码 MP3 为 PCM
        // 这里简化实现，实际需要使用 AudioToolbox 解码
        
        // TODO: 实现 MP3 解码
        // 当前可以先使用 AVPlayer 播放完整文件
        Logger.debug("播放音频数据: \(data.count) 字节")
    }
    
    func stop() {
        playerNode?.stop()
        audioEngine?.stop()
        Logger.info("音频播放已停止")
    }
}
