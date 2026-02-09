//
//  SummarizationService.swift
//  SmartBook
//
//  Created on 06/02/2026.
//

import Foundation

/// 对话摘要服务
@MainActor
class SummarizationService {
    
    // MARK: - Properties
    
    /// 摘要触发阈值（同时也是保留的历史消息数量）
    private let threshold: Int
    
    /// 流式聊天服务（用于生成摘要）
    private let streamingService: StreamingChatService
    
    /// 摘要助手（静态常量，避免重复创建）
    private static let summaryAssistant = Assistant(
        id: "summarize",
        name: "摘要助手",
        avatar: "📝",
        color: "#9c27b0",
        description: "对话摘要助手",
        systemPrompt: "你是一个专业的对话摘要助手。",
        action: .chat,
        useRAG: false
    )
    
    // MARK: - Initialization
    
    init(threshold: Int = 3, streamingService: StreamingChatService = StreamingChatService()) {
        self.threshold = threshold
        self.streamingService = streamingService
    }
    
    // MARK: - Public Methods
    
    /// 获取对话上下文（摘要 + 最近消息）
    /// - Parameters:
    ///   - messages: 所有消息
    ///   - conversation: 当前对话
    /// - Returns: (摘要文本, 最近消息数组)
    func getContext(messages: [ChatMessage], conversation: Conversation?) -> (String?, [ChatMessage]) {
        guard let conversation = conversation else {
            return (nil, Array(messages.suffix(threshold)))
        }

        let summarizedCount = conversation.summarizedMessageCount

        // 如果有摘要，返回摘要 + 未摘要的最近N条消息
        if let summary = conversation.summary, summarizedCount > 0 {
            let unsummarizedMessages = Array(messages.dropFirst(summarizedCount))
            let recentMessages = Array(unsummarizedMessages.suffix(threshold))
            Logger.info("📝 使用摘要 (\(summarizedCount)条) + 最近\(recentMessages.count)条消息")
            return (summary, recentMessages)
        }

        // 没有摘要，返回最近N条
        let recentMessages = Array(messages.suffix(threshold))
        return (nil, recentMessages)
    }
    
    /// 检查并触发摘要生成（如果需要）
    /// - Parameters:
    ///   - messages: 所有消息
    ///   - conversation: 当前对话
    ///   - historyService: 历史服务（用于保存）
    func checkAndTriggerSummarization(
        messages: [ChatMessage],
        conversation: Conversation?,
        historyService: ChatHistoryService?
    ) {
        guard let conversation = conversation else { return }

        let totalMessages = messages.count
        let summarizedCount = conversation.summarizedMessageCount
        let unsummarizedCount = totalMessages - summarizedCount
        
        // threshold 代表轮数（1轮=用户+AI=2条消息）
        // 例：threshold=3 → 3轮对话 → 6条消息
        let roundThreshold = threshold * 2

        // 当未摘要消息数超过阈值时触发
        if unsummarizedCount > roundThreshold {
            Task {
                await generateSummary(
                    messages: messages,
                    conversation: conversation,
                    historyService: historyService
                )
            }
        }
    }
    
    /// 生成对话摘要
    /// - Parameters:
    ///   - messages: 所有消息
    ///   - conversation: 当前对话
    ///   - historyService: 历史服务（用于保存）
    func generateSummary(
        messages: [ChatMessage],
        conversation: Conversation,
        historyService: ChatHistoryService?
    ) async {
        let summarizedCount = conversation.summarizedMessageCount
        let unsummarizedMessages = Array(messages.dropFirst(summarizedCount))
        
        // 摘要所有未摘要消息，但保留最近N条作为历史
        let messagesToSummarize = Array(unsummarizedMessages.dropLast(threshold))

        guard !messagesToSummarize.isEmpty else {
            return
        }

        Logger.info("🤖 开始生成摘要，处理 \(messagesToSummarize.count) 条消息（保留最近\(threshold)条作为历史）...")

        // 构建摘要请求（使用英文 + 语言指令）
        var conversationText = ""
        if let existingSummary = conversation.summary {
            conversationText += "Previous summary of earlier conversation:\n\(existingSummary)\n\n"
            conversationText += "New conversation since the summary:\n"
        }

        for msg in messagesToSummarize {
            let role = msg.role == .user ? "User" : "AI"
            conversationText += "\(role): \(msg.content)\n\n"
        }

        // 获取当前语言
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let languageName = currentLanguage == "zh" ? "Chinese" : "English"
        
        let summarizePrompt = """
            Please concisely summarize the key points of the above conversation, including: 1) The main topics discussed by the user 2) The key information and conclusions provided by AI 3) Any important background context. The summary should be brief and concise (100-200 words) for reference in subsequent conversations. If you can speak in \(languageName), then respond in \(languageName).
            """

        // 调用 AI 生成摘要（使用流式 API）
        var generatedSummary = ""

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            streamingService.sendMessageStream(
                message: conversationText + "\n\n" + summarizePrompt,
                assistant: Self.summaryAssistant,
                bookId: nil,
                model: "gemini-2.0-flash",
                ragEnabled: false,
                summary: nil,
                history: []
            ) { event in
                if case .content(let content) = event {
                    generatedSummary += content
                }
            } onComplete: { _ in
                continuation.resume()
            }
        }

        // 保存生成的摘要
        guard !generatedSummary.isEmpty else {
            Logger.error("❌ 摘要生成失败，内容为空")
            return
        }
        
        conversation.summary = generatedSummary
        conversation.summarizedMessageCount = summarizedCount + messagesToSummarize.count
        conversation.touch()
        
        // 通过 historyService 保存到数据库
        historyService?.saveSummary(summary: generatedSummary, messageCount: conversation.summarizedMessageCount)
        
        Logger.info("✅ AI 摘要已保存，已摘要消息数: \(conversation.summarizedMessageCount)")
        Logger.info("📝 摘要内容: \(generatedSummary.prefix(100))...")
    }
}
