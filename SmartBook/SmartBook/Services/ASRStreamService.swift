// ASRStreamService.swift - 实时流式语音识别服务
// 使用 WebSocket 连接后端，实现边说边识别

import Foundation
import AVFoundation
import Combine

class ASRStreamService: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var isConnected = false
    @Published var error: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private var audioFormat: AVAudioFormat?
    
    private var onTranscriptUpdate: ((String, Bool) -> Void)?
    private var onDeepgramReady: (() -> Void)?
    
    override init() {
        super.init()
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
            components.port = 8083  // 强制使用 8083 端口
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
        
        // 发送开始消息
        let startMessage: [String: Any] = [
            "type": "start",
            "language": language,
            "model": model
        ]
        
        await sendMessage(startMessage)
        
        Logger.info("WebSocket 连接成功，已发送 start 消息")
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
                Logger.error("WebSocket 接收错误: \(error.localizedDescription)")
                Task { @MainActor in
                    self.error = error.localizedDescription
                    self.isConnected = false
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
                Logger.info("WebSocket 连接成功")
                
            case "started":
                Logger.info("识别已启动，Deepgram 准备就绪")
                // 通知 Deepgram 已就绪，可以开始录音
                self.onDeepgramReady?()
                
            case "transcript":
                let transcript = json["transcript"] as? String ?? ""
                let isFinal = json["is_final"] as? Bool ?? false
                let confidence = json["confidence"] as? Double ?? 0
                
                Logger.info("识别结果: \(transcript) [isFinal: \(isFinal), confidence: \(confidence)]")
                
                // 更新文本
                self.transcript = transcript
                
                // 调用回调
                self.onTranscriptUpdate?(transcript, isFinal)
                
            case "stopped":
                Logger.info("识别已停止")
                self.isRecording = false
                
            case "error":
                let errorMsg = json["message"] as? String ?? "Unknown error"
                Logger.error("服务器错误: \(errorMsg)")
                self.error = errorMsg
                
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
    
    // MARK: - 录音控制
    
    @MainActor
    func startRecording(
        onDeepgramReady: @escaping () -> Void,
        onTranscriptUpdate: @escaping (String, Bool) -> Void
    ) {
        self.onDeepgramReady = onDeepgramReady
        self.onTranscriptUpdate = onTranscriptUpdate
        
        guard isConnected else {
            self.error = "WebSocket 未连接"
            return
        }
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true)
        } catch {
            Logger.error("音频会话配置失败: \(error)")
            self.error = "音频会话配置失败"
            return
        }
        
        // 配置音频格式：16kHz, 单声道, 16-bit PCM
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // 创建目标格式：16kHz, Int16, Interleaved（Deepgram 要求）
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true  // ✅ 修改为 true！Deepgram 需要交错格式
        ) else {
            self.error = "无法创建音频格式"
            return
        }
        
        self.audioFormat = targetFormat
        
        // 创建格式转换器
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            self.error = "无法创建音频转换器"
            return
        }
        
        // 安装音频采集
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // 转换音频格式
            self.convertAndSendAudio(buffer: buffer, converter: converter, targetFormat: targetFormat)
        }
        
        // 启动音频引擎
        do {
            try audioEngine.start()
            isRecording = true
            Logger.info("开始录音（流式识别）")
        } catch {
            Logger.error("音频引擎启动失败: \(error)")
            self.error = "无法启动录音"
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
        Logger.info("停止录音")
    }
    
    // MARK: - 音频处理
    
    private func convertAndSendAudio(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        // 创建输出缓冲区
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: capacity
        ) else {
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
}
