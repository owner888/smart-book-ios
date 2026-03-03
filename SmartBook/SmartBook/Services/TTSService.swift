// TTSService.swift - 文字转语音服务（使用原生 AVSpeechSynthesizer，免费）

import AVFoundation
import Combine
import Foundation
import SwiftUI

class TTSService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []

    private var synthesizer: AVSpeechSynthesizer?
    private var onComplete: (() -> Void)?
    private var hasLoadedVoices = false

    @AppStorage(AppConfig.Keys.selectedVoice) private var selectedVoiceId = ""

    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var selectedVoice: AVSpeechSynthesisVoice? {
        didSet {
            selectedVoiceId = selectedVoice?.identifier ?? ""
        }
    }

    override init() {
        super.init()
    }

    private func getSynthesizer() -> AVSpeechSynthesizer {
        if let synthesizer {
            return synthesizer
        }
        let newSynthesizer = AVSpeechSynthesizer()
        newSynthesizer.delegate = self
        synthesizer = newSynthesizer
        return newSynthesizer
    }

    // MARK: - 加载可用语音
    func loadVoices(force: Bool = false) {
        if hasLoadedVoices && !force {
            return
        }

        // 获取中文语音
        availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("zh")
        }

        hasLoadedVoices = true

        // 选择默认语音（优先选择高质量语音）
        selectedVoice =
            availableVoices.first { $0.identifier == selectedVoiceId }
            ??
            availableVoices.first { $0.quality == .enhanced }
            ?? availableVoices.first { $0.language == "zh-CN" }
            ?? availableVoices.first

        Logger.debug("TTS voices loaded: \(availableVoices.count)")
    }

    func ensureVoicesLoaded() {
        loadVoices()
    }

    // MARK: - 朗读文本
    @MainActor
    func speak(_ text: String) async {
        ensureVoicesLoaded()

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
            getSynthesizer().speak(utterance)
        }
    }

    // MARK: - 停止朗读
    @MainActor
    func stop() {
        guard let synthesizer else {
            isSpeaking = false
            return
        }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    // MARK: - 暂停/继续
    func pause() {
        guard let synthesizer else { return }
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        guard let synthesizer else { return }
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
