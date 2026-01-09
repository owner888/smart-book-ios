// SpeechService.swift - 语音识别服务（使用原生 Speech Framework，免费）

import Foundation
import Speech
import AVFoundation

@Observable
class SpeechService {
    var isRecording = false
    var transcript = ""
    var isAuthorized = false
    
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()
    
    private var onInterimResult: ((String) -> Void)?
    private var onFinalResult: ((String) -> Void)?
    
    init() {
        // 使用中文识别器
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        
        Task {
            await requestAuthorization()
        }
    }
    
    // MARK: - 请求权限
    @MainActor
    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        isAuthorized = (status == .authorized)
        
        if !isAuthorized {
            print("⚠️ 语音识别权限未授权")
        }
    }
    
    // MARK: - 开始录音
    @MainActor
    func startRecording(
        onInterim: @escaping (String) -> Void,
        onFinal: @escaping (String) -> Void
    ) {
        guard isAuthorized else {
            print("⚠️ 语音识别未授权")
            return
        }
        
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("⚠️ 语音识别不可用")
            return
        }
        
        // 保存回调
        self.onInterimResult = onInterim
        self.onFinalResult = onFinal
        
        // 停止之前的任务
        stopRecording()
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ 音频会话配置失败: \(error)")
            return
        }
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // 设置为 true 可离线识别
        
        // 配置音频输入
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // 开始识别任务
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                Task { @MainActor in
                    self.transcript = text
                    self.onInterimResult?(text)
                    
                    if result.isFinal {
                        self.onFinalResult?(text)
                        self.stopRecording()
                    }
                }
            }
            
            if let error = error {
                print("❌ 识别错误: \(error)")
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }
        
        // 启动音频引擎
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            print("🎤 开始录音")
        } catch {
            print("❌ 音频引擎启动失败: \(error)")
        }
    }
    
    // MARK: - 停止录音
    @MainActor
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        print("🎤 停止录音")
    }
    
    // MARK: - 切换语言
    func setLanguage(_ locale: Locale) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }
}
