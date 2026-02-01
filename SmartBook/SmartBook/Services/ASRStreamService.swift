// ASRStreamService.swift - 实时流式语音识别服务
// 使用 WebSocket 连接后端，实现边说边识别

import AVFoundation
import Combine
import Foundation

class ASRStreamService: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var isConnected = false
    @Published var error: String?
    @Published var audioLevel: Float = 0.0  // 音频音量级别 (0.0-1.0)
    @Published var isDetectingAudio = false  // 是否检测到音频
    @Published var statusMessage: String?  // 状态提示消息

    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private var audioFormat: AVAudioFormat?

    private var onTranscriptUpdate: ((String, Bool) -> Void)?
    private var onDeepgramReady: (() -> Void)?
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var shouldAutoReconnect = true  // 是否自动重连
    private var reconnectAttempts = 0
    private var lastTranscriptTime: Date?  // 最后收到识别结果的时间
    private var noAudioTimer: Timer?  // 无音频检测计时器
    private var deepgramConnectionTime: Date?  // Deepgram 连接时间

    override init() {
        super.init()
    }

    deinit {
        heartbeatTimer?.invalidate()
        reconnectTimer?.invalidate()
        noAudioTimer?.invalidate()
        shouldAutoReconnect = false
    }

    // MARK: - WebSocket 连接

    @MainActor
    func connect(language: String = "zh-CN", model: String = "nova-2") async {
        // 构建 WebSocket URL
        var wsURL = AppConfig.apiBaseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")

        // 移除路径部分，只保留 host:port
        if let urlComponents = URLComponents(string: wsURL) {
            var components = urlComponents
            components.path = ""
            components.port = 9525  // ASR WebSocket 端口
            wsURL = components.string ?? wsURL
        }

        Logger.info("原始 API URL: \(AppConfig.apiBaseURL)")
        Logger.info("WebSocket URL: \(wsURL)")

        guard let url = URL(string: wsURL) else {
            self.error = "无效的 WebSocket URL"
            Logger.error("无效的 WebSocket URL: \(wsURL)")
            return
        }

        // 创建 WebSocket 连接
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true

        // 开始接收消息
        receiveMessage()

        // 启动心跳保持连接
        startHeartbeat()

        Logger.info("WebSocket 连接成功，心跳已启动")
    }

    @MainActor
    func disconnect() async {
        guard isConnected else { return }

        // 发送停止消息
        let stopMessage: [String: Any] = ["type": "stop"]
        await sendMessage(stopMessage)

        // 关闭连接
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false

        Logger.info("WebSocket 连接已关闭")
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
                case .data:
                    // 不处理二进制消息
                    break
                @unknown default:
                    break
                }

                // 继续接收下一条消息
                self.receiveMessage()

            case .failure(let error):
                Logger.error("ASR WebSocket Error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.error = error.localizedDescription
                    self.isConnected = false

                    // 触发自动重连
                    self.startAutoReconnect()
                }
            }
        }
    }

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
                Logger.info("WebSocket 连接成功")
                
            case "connecting":
                let message = json["message"] as? String ?? "正在连接 Deepgram..."
                Logger.info("📡 \(message)")
                self.statusMessage = "📡 正在连接语音识别服务..."

            case "started":
                Logger.info("识别已启动，Deepgram 准备就绪")
                self.deepgramConnectionTime = Date()
                self.statusMessage = "🎤 开始说话..."
                
                // 启动无音频检测计时器（15秒后如果没有识别结果，给出提示）
                self.startNoAudioDetectionTimer()
                
                // 通知 Deepgram 已就绪，可以开始录音
                self.onDeepgramReady?()

            case "transcript":
                let transcript = json["transcript"] as? String ?? ""
                let isFinal = json["is_final"] as? Bool ?? false
                let confidence = json["confidence"] as? Double ?? 0

                Logger.info("识别结果: \(transcript) [isFinal: \(isFinal), confidence: \(confidence)]")

                // 更新最后识别时间
                self.lastTranscriptTime = Date()
                
                // 清除状态消息
                self.statusMessage = nil
                
                // 重置无音频检测计时器
                self.resetNoAudioDetectionTimer()

                // 更新文本
                self.transcript = transcript

                // 调用回调
                self.onTranscriptUpdate?(transcript, isFinal)

            case "stopped":
                Logger.info("识别已停止")
                self.isRecording = false

            case "deepgram_closed":
                let message = json["message"] as? String
                Logger.info("Deepgram 连接已关闭: \(message ?? "")")
                self.isRecording = false
                
                // 如果是在录音过程中断开（非主动停止），显示警告
                if self.isRecording {
                    self.statusMessage = "⚠️ 语音识别服务已断开，请重新开始"
                } else {
                    // 主动停止的情况，不显示错误
                    self.statusMessage = nil
                }
                
                self.stopNoAudioDetectionTimer()

            case "error":
                let errorMsg = json["message"] as? String ?? "Unknown error"
                let originalError = json["original_error"] as? String
                
                Logger.error("服务器错误: \(errorMsg)")
                if let originalError = originalError {
                    Logger.error("原始错误: \(originalError)")
                }
                
                self.error = errorMsg
                
                // 根据错误类型显示不同的状态消息
                if errorMsg.contains("API") || errorMsg.contains("认证") {
                    self.statusMessage = "❌ API 配置错误，请联系管理员"
                } else if errorMsg.contains("网络") || errorMsg.contains("连接") || errorMsg.contains("超时") {
                    self.statusMessage = "❌ 网络连接失败，请检查网络"
                } else if errorMsg.contains("DNS") {
                    self.statusMessage = "❌ 网络配置错误"
                } else if errorMsg.contains("不可用") || errorMsg.contains("503") {
                    self.statusMessage = "❌ 服务暂时不可用，请稍后再试"
                } else if errorMsg.contains("频率") || errorMsg.contains("超限") {
                    self.statusMessage = "❌ 使用频率过高，请稍后再试"
                } else {
                    self.statusMessage = "❌ \(errorMsg)"
                }
                
                self.stopNoAudioDetectionTimer()

            case "pong":
                // 心跳响应
                break

            default:
                Logger.info("未知消息类型: \(type)")
            }
        }
    }

    private func sendMessage(_ message: [String: Any]) async {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
            let text = String(data: data, encoding: .utf8)
        else {
            return
        }

        let message = URLSessionWebSocketTask.Message.string(text)

        do {
            try await webSocketTask?.send(message)
        } catch {
            Logger.error("发送消息失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 录音控制

    @MainActor
    func startRecording(
        language: String = "zh-CN",
        model: String = "nova-2",
        onDeepgramReady: @escaping () -> Void,
        onTranscriptUpdate: @escaping (String, Bool) -> Void
    ) {
        // 保存回调，等待 Deepgram 就绪后再启动音频引擎
        self.onDeepgramReady = { [weak self] in
            guard let self = self else { return }
            // Deepgram 就绪，启动音频引擎
            Task { @MainActor in
                self.startAudioEngine()
                // 调用外部的就绪回调
                onDeepgramReady()
            }
        }
        self.onTranscriptUpdate = onTranscriptUpdate

        guard isConnected else {
            self.error = "WebSocket 未连接"
            return
        }

        // 发送 start 消息，触发 Deepgram 连接
        Task {
            let startMessage: [String: Any] = [
                "type": "start",
                "language": language,
                "model": model,
            ]
            await sendMessage(startMessage)
            Logger.info("已发送 start 消息，等待 Deepgram 就绪...")
        }
    }

    // 启动音频引擎（Deepgram 就绪后调用）
    @MainActor
    private func startAudioEngine() {
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true)
        } catch {
            Logger.error("音频会话配置失败: \(error)")
            self.error = "音频会话配置失败"
            self.statusMessage = "❌ 麦克风配置失败"
            return
        }

        // 配置音频格式：16kHz, 单声道, 16-bit PCM
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // 创建目标格式：16kHz, Int16, Interleaved（Deepgram 要求）
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16000,
                channels: 1,
                interleaved: true  // ✅ Deepgram 需要交错格式
            )
        else {
            self.error = "无法创建音频格式"
            self.statusMessage = "❌ 音频格式错误"
            return
        }

        self.audioFormat = targetFormat

        // 创建格式转换器
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            self.error = "无法创建音频转换器"
            self.statusMessage = "❌ 音频转换器错误"
            return
        }

        // 安装音频采集
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // 计算音频音量级别
            self.calculateAudioLevel(buffer: buffer)
            
            // 转换音频格式
            self.convertAndSendAudio(buffer: buffer, converter: converter, targetFormat: targetFormat)
        }

        // 启动音频引擎
        do {
            try audioEngine.start()
            isRecording = true
            Logger.info("✅ 音频引擎已启动，开始录音")
        } catch {
            Logger.error("音频引擎启动失败: \(error)")
            self.error = "无法启动录音"
            self.statusMessage = "❌ 无法启动录音"
        }
    }

    @MainActor
    func stopRecording() {
        guard isRecording else {
            Logger.debug("录音未在进行中，忽略停止请求")
            return
        }

        // 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        isRecording = false
        audioLevel = 0.0
        isDetectingAudio = false
        statusMessage = nil
        
        // 停止无音频检测计时器
        stopNoAudioDetectionTimer()

        // 发送 stop 消息，让服务器断开 Deepgram
        Task {
            let stopMessage: [String: Any] = ["type": "stop"]
            await sendMessage(stopMessage)
            Logger.info("停止录音，已发送 stop 消息")
        }
    }

    // MARK: - 音频音量检测
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        // 计算 RMS（均方根）
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(rms)
        
        // 归一化到 0-1 范围（-60dB 到 0dB）
        let normalizedLevel = max(0, min(1, (db + 60) / 60))
        
        Task { @MainActor in
            self.audioLevel = normalizedLevel
            
            // 检测是否有声音（阈值 0.1）
            let hasAudio = normalizedLevel > 0.1
            if hasAudio != self.isDetectingAudio {
                self.isDetectingAudio = hasAudio
                if hasAudio {
                    Logger.debug("🎤 检测到声音，音量: \(normalizedLevel)")
                }
            }
        }
    }
    
    // MARK: - 无音频检测计时器
    
    private func startNoAudioDetectionTimer() {
        stopNoAudioDetectionTimer()
        
        noAudioTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                // 检查是否长时间没有识别结果
                if let lastTime = self.lastTranscriptTime {
                    let timeSinceLastTranscript = Date().timeIntervalSince(lastTime)
                    if timeSinceLastTranscript > 10 {
                        if self.isDetectingAudio {
                            self.statusMessage = "🔊 检测到声音但无法识别，请说清楚一点"
                        } else {
                            self.statusMessage = "🤔 没有检测到声音，请靠近麦克风说话"
                        }
                    }
                } else if let connectionTime = self.deepgramConnectionTime {
                    let timeSinceConnection = Date().timeIntervalSince(connectionTime)
                    if timeSinceConnection > 8 {
                        if self.isDetectingAudio {
                            self.statusMessage = "🔊 检测到声音但无法识别，请说清楚一点"
                        } else {
                            self.statusMessage = "🤔 没有检测到声音，请靠近麦克风说话"
                        }
                    }
                }
            }
        }
    }
    
    private func resetNoAudioDetectionTimer() {
        // 重新启动计时器
        startNoAudioDetectionTimer()
    }
    
    private func stopNoAudioDetectionTimer() {
        noAudioTimer?.invalidate()
        noAudioTimer = nil
    }
    
    // MARK: - 音频处理

    private func convertAndSendAudio(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        // 创建输出缓冲区
        let capacity = AVAudioFrameCount(
            Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate
        )
        guard
            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: capacity
            )
        else {
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            Logger.error("音频转换失败: \(error)")
            return
        }

        // 转换为 Data
        guard let audioData = bufferToData(convertedBuffer) else {
            return
        }

        // 发送音频数据
        Task {
            await sendAudioData(audioData)
        }
    }

    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else {
            return nil
        }

        let channelDataPointer = channelData.pointee
        let dataSize = Int(buffer.frameLength) * MemoryLayout<Int16>.size

        return Data(bytes: channelDataPointer, count: dataSize)
    }

    private func sendAudioData(_ data: Data) async {
        let message = URLSessionWebSocketTask.Message.data(data)

        do {
            try await webSocketTask?.send(message)
        } catch {
            // 忽略发送错误，避免日志刷屏
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
        // 如果不允许自动重连，直接返回
        guard shouldAutoReconnect else { return }

        reconnectAttempts += 1

        // 计算重连延迟（指数退避，最大 30 秒）
        let delay = min(Double(reconnectAttempts) * 2.0, 30.0)

        Logger.info("🔄 将在 \(delay) 秒后重连（第 \(reconnectAttempts) 次）")

        // 取消之前的重连计时器
        reconnectTimer?.invalidate()

        // 创建新的重连计时器
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                Logger.info("🔄 尝试重新连接...")
                await self.connect()

                // 如果连接成功，重置重连计数
                if self.isConnected {
                    self.reconnectAttempts = 0
                    Logger.info("✅ 重连成功")
                }
            }
        }
    }

    // 停止自动重连
    @MainActor
    func stopAutoReconnect() {
        shouldAutoReconnect = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        Logger.info("⏹️ 已停止自动重连")
    }

    // 启用自动重连
    @MainActor
    func enableAutoReconnect() {
        shouldAutoReconnect = true
        Logger.info("▶️ 已启用自动重连")
    }
}
