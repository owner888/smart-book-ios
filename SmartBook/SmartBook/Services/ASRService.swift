// ASRService.swift - 后端 ASR 服务（Google/Deepgram）
// 通过后端 API 调用语音识别服务

import Foundation
import AVFoundation
import Combine

/// ASR 提供商类型
enum ASRProvider: String, CaseIterable, Identifiable {
    case native = "native"      // iOS 原生 Speech Framework
    case google = "google"      // Google Cloud Speech-to-Text
    case deepgram = "deepgram" // Deepgram ASR
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .native: return "iOS 原生（免费）"
        case .google: return "Google ASR"
        case .deepgram: return "Deepgram（推荐）"
        }
    }
    
    var description: String {
        switch self {
        case .native:
            return "使用 iOS 原生语音识别，免费但需要网络连接"
        case .google:
            return "使用 Google Cloud 语音识别，高精度但费用较高（$0.024/分钟）"
        case .deepgram:
            return "使用 Deepgram 语音识别，高精度且费用低（$0.0043/分钟）"
        }
    }
}

/// ASR 配置信息
struct ASRConfig: Codable {
    let provider: String
    let defaultLanguage: String
    let languages: [String: String]
    var models: [String: String]?
    var defaultModel: String?
    
    enum CodingKeys: String, CodingKey {
        case provider
        case defaultLanguage = "default_language"
        case languages
        case models
        case defaultModel = "default_model"
    }
}

/// ASR 识别结果
struct ASRResult: Codable {
    let transcript: String
    let confidence: Double
    let language: String
    let duration: Double
    let cost: Double
    let costFormatted: String
    let provider: String
    var words: [ASRWord]?
    var utterances: [ASRUtterance]?
    var requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case transcript, confidence, language, duration, cost
        case costFormatted = "costFormatted"
        case provider, words, utterances
        case requestId = "request_id"
    }
}

/// ASR 单词信息
struct ASRWord: Codable {
    let word: String
    let start: Double
    let end: Double
    let confidence: Double
}

/// ASR 分段信息
struct ASRUtterance: Codable {
    let transcript: String
    let start: Double
    let end: Double
    let confidence: Double
}

class ASRService: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var error: String?
    @Published var config: ASRConfig?
    var selectedLanguage: String = AppConfig.DefaultValues.asrLanguage
    
    private let audioEngine = AVAudioEngine()
    private var audioBuffer = Data()
    private var recordingStartTime: Date?
    
    private var onInterimResult: ((String) -> Void)?
    private var onFinalResult: ((String) -> Void)?
    
    init() {
        // 从 UserDefaults 读取语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: AppConfig.Keys.asrLanguage) {
            selectedLanguage = savedLanguage
        }
        
        Task {
            await loadConfig()
        }
    }
    
    // MARK: - 加载配置
    @MainActor
    func loadConfig() async {
        do {
            let urlString = "\(AppConfig.apiBaseURL)/api/asr/config"
            guard let url = URL(string: urlString) else {
                Logger.error("无效的 API URL: \(urlString)")
                return
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            struct Response: Codable {
                let success: Bool
                let data: ASRConfig
            }
            
            let response = try JSONDecoder().decode(Response.self, from: data)
            self.config = response.data
            
            Logger.info("ASR 配置加载成功：\(response.data.provider)")
        } catch {
            Logger.error("加载 ASR 配置失败: \(error)")
        }
    }
    
    // MARK: - 开始录音
    @MainActor
    func startRecording(
        onInterim: @escaping (String) -> Void,
        onFinal: @escaping (String) -> Void
    ) {
        // 保存回调
        self.onInterimResult = onInterim
        self.onFinalResult = onFinal
        
        // 停止之前的录音
        stopRecording()
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            Logger.error("音频会话配置失败: \(error)")
            self.error = ASRError.audioSessionFailed.localizedDescription
            return
        }
        
        // 重置音频缓冲区
        audioBuffer = Data()
        recordingStartTime = Date()
        
        // 配置音频输入
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // 转换为 Data
            let audioData = self.bufferToData(buffer: buffer)
            self.audioBuffer.append(audioData)
        }
        
        // 启动音频引擎
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            Logger.info("开始录音（后端 ASR）")
        } catch {
            Logger.error("音频引擎启动失败: \(error)")
            self.error = ASRError.recordingFailed.localizedDescription
        }
    }
    
    // MARK: - 停止录音并识别
    @MainActor
    func stopRecording() {
        guard isRecording else { return }
        
        // 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        isRecording = false
        Logger.info("停止录音")
        
        // 如果有录音数据，发送到服务器识别
        if !audioBuffer.isEmpty {
            Task {
                await recognizeAudio()
            }
        }
    }
    
    // MARK: - 识别音频
    @MainActor
    private func recognizeAudio() async {
        guard !audioBuffer.isEmpty else {
            Logger.warning("没有录音数据")
            return
        }
        
        Logger.info("开始识别音频，大小: \(audioBuffer.count) bytes")
        
        do {
            // 将音频数据转换为 WAV 格式
            let wavData = try convertToWAV(pcmData: audioBuffer)
            
            // Base64 编码
            let base64Audio = wavData.base64EncodedString()
            
            // ✅ 使用 APIClient 发送请求
            let requestBody: [String: Any] = [
                "audio": base64Audio,
                "encoding": "LINEAR16",
                "sample_rate": 48000,
                "language": selectedLanguage,
                "model": config?.defaultModel ?? "nova-2"
            ]
            
            let (data, httpResponse) = try await APIClient.shared.post(
                "/api/asr/recognize",
                body: requestBody,
                timeout: 60  // ASR 可能需要较长时间
            )
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.from(statusCode: httpResponse.statusCode)
            }
            
            // 尝试解析两种格式的响应
            // 格式1: { "success": true, "data": { ... } }
            // 格式2: { "success": true, "transcript": "...", ... }
            
            struct WrappedResponse: Codable {
                let success: Bool
                let data: ASRResult
            }
            
            struct DirectResponse: Codable {
                let success: Bool
                let transcript: String
                let confidence: Double
                let language: String
                let duration: Double
                let cost: Double
                let costFormatted: String
                let provider: String
                var words: [ASRWord]?
                var utterances: [ASRUtterance]?
                var requestId: String?
                
                enum CodingKeys: String, CodingKey {
                    case success, transcript, confidence, language, duration, cost
                    case costFormatted, provider, words, utterances
                    case requestId = "request_id"
                }
                
                func toASRResult() -> ASRResult {
                    return ASRResult(
                        transcript: transcript,
                        confidence: confidence,
                        language: language,
                        duration: duration,
                        cost: cost,
                        costFormatted: costFormatted,
                        provider: provider,
                        words: words,
                        utterances: utterances,
                        requestId: requestId
                    )
                }
            }
            
            let asrResult: ASRResult
            
            // 先尝试解析包装格式
            if let wrappedResponse = try? JSONDecoder().decode(WrappedResponse.self, from: data) {
                guard wrappedResponse.success else {
                    throw ASRError.recognitionFailed
                }
                asrResult = wrappedResponse.data
            }
            // 再尝试直接格式
            else if let directResponse = try? JSONDecoder().decode(DirectResponse.self, from: data) {
                guard directResponse.success else {
                    throw ASRError.recognitionFailed
                }
                asrResult = directResponse.toASRResult()
            }
            else {
                throw APIError.parseError
            }
            
            let text = asrResult.transcript
            self.transcript = text
            
            Logger.info("识别成功: \(text)")
            Logger.info("置信度: \(asrResult.confidence)%")
            Logger.info("提供商: \(asrResult.provider)")
            Logger.info("费用: \(asrResult.costFormatted)")
            
            // 调用最终结果回调
            self.onFinalResult?(text)
            
        } catch {
            Logger.error("识别失败: \(error)")
            self.error = error.localizedDescription
        }
        
        // 清空缓冲区
        audioBuffer = Data()
    }
    
    // MARK: - 辅助方法
    
    /// 将音频缓冲区转换为 Data
    private func bufferToData(buffer: AVAudioPCMBuffer) -> Data {
        let channelData = buffer.floatChannelData![0]
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelData[$0] }
        
        var data = Data()
        for sample in channelDataValueArray {
            // 转换为 16-bit PCM
            let int16Sample = Int16(sample * 32767.0)
            var value = int16Sample
            data.append(Data(bytes: &value, count: MemoryLayout<Int16>.size))
        }
        
        return data
    }
    
    /// 将 PCM 数据转换为 WAV 格式
    private func convertToWAV(pcmData: Data) throws -> Data {
        let sampleRate: UInt32 = 48000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample) / 8
        let blockAlign = numChannels * bitsPerSample / 8
        
        var wavData = Data()
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        var fileSize = UInt32(36 + pcmData.count)
        wavData.append(Data(bytes: &fileSize, count: 4))
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        var fmtSize: UInt32 = 16
        wavData.append(Data(bytes: &fmtSize, count: 4))
        var audioFormat: UInt16 = 1 // PCM
        wavData.append(Data(bytes: &audioFormat, count: 2))
        var channels = numChannels
        wavData.append(Data(bytes: &channels, count: 2))
        var rate = sampleRate
        wavData.append(Data(bytes: &rate, count: 4))
        var byteRateValue = byteRate
        wavData.append(Data(bytes: &byteRateValue, count: 4))
        var blockAlignValue = blockAlign
        wavData.append(Data(bytes: &blockAlignValue, count: 2))
        var bps = bitsPerSample
        wavData.append(Data(bytes: &bps, count: 2))
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        var dataSize = UInt32(pcmData.count)
        wavData.append(Data(bytes: &dataSize, count: 4))
        wavData.append(pcmData)
        
        return wavData
    }
}
