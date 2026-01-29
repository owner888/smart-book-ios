// TTSService.swift - 文字转语音服务（使用原生 AVSpeechSynthesizer，免费）

import Foundation
import AVFoundation
import Combine

class TTSService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    
    private let synthesizer = AVSpeechSynthesizer()
    private var onComplete: (() -> Void)?
    
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var selectedVoice: AVSpeechSynthesisVoice?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        loadVoices()
    }
    
    // MARK: - 加载可用语音
    func loadVoices() {
        // 获取中文语音
        availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("zh")
        }
        
        // 选择默认语音（优先选择高质量语音）
        selectedVoice = availableVoices.first { $0.quality == .enhanced }
            ?? availableVoices.first { $0.language == "zh-CN" }
            ?? availableVoices.first
        
        Logger.info("可用中文语音: \(availableVoices.map { $0.name })")
        Logger.info("选择语音: \(selectedVoice?.name ?? "无")")
    }
    
    // MARK: - 朗读文本
    @MainActor
    func speak(_ text: String) async {
        // 清理文本（移除 Markdown 等）
        let cleanText = cleanMarkdown(text)
        guard !cleanText.isEmpty else { return }
        
        // 停止当前播放
        stop()
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
            try audioSession.setActive(true)
        } catch {
            Logger.error("音频会话配置失败: \(error)")
        }
        
        // 创建语音请求
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        if let voice = selectedVoice {
            utterance.voice = voice
        }
        
        // 使用 continuation 等待完成
        await withCheckedContinuation { continuation in
            self.onComplete = {
                continuation.resume()
            }
            
            isSpeaking = true
            synthesizer.speak(utterance)
        }
    }
    
    // MARK: - 停止朗读
    @MainActor
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    // MARK: - 暂停/继续
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }
    
    func resume() {
        synthesizer.continueSpeaking()
    }
    
    // MARK: - 清理 Markdown
    private func cleanMarkdown(_ text: String) -> String {
        var cleaned = text
        
        // 移除工具调用信息
        cleaned = cleaned.replacingOccurrences(of: #"^>\s*🔧.*$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"^>\s*✅.*$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"^>\s*❌.*$"#, with: "", options: .regularExpression)
        
        // 移除代码块
        cleaned = cleaned.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "", options: .regularExpression)
        
        // 移除行内代码
        cleaned = cleaned.replacingOccurrences(of: #"`[^`]+`"#, with: "", options: .regularExpression)
        
        // 移除链接，保留文字
        cleaned = cleaned.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        
        // 移除 Markdown 格式符号
        cleaned = cleaned.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"^#+\s+"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"^>\s+"#, with: "", options: .regularExpression)
        
        // 压缩空白
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            onComplete?()
            onComplete = nil
            Logger.info("朗读完成")
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            onComplete?()
            onComplete = nil
        }
    }
}
