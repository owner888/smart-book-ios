// ChatService.swift - 流式聊天服务（支持SSE流式响应）

import Foundation

// MARK: - 流式聊天服务
@Observable
class StreamingChatService: NSObject {
    var isStreaming = false
    var currentTask: URLSessionDataTask?
    private var receivedData = Data()
    private var onEventHandler: SSEEventHandler?
    private var onCompleteHandler: CompletionHandler?
    private var buffer = ""  // 添加缓冲区，避免 SSE 数据丢失

    // SSE 事件处理闭包
    typealias SSEEventHandler = (SSEEvent) -> Void
    typealias CompletionHandler = (Result<Void, Error>) -> Void

    override init() {
        super.init()
    }

    deinit {
        // 清理资源
        currentTask?.cancel()
    }

    // 发送消息（SSE 流式）
    func sendMessageStream(
        message: String,
        assistant: Assistant,
        bookId: String?,
        model: String = AppConfig.DefaultValues.defaultModel,
        enableRag: Bool = false,
        summary: String? = nil,
        history: [ChatMessage] = [],
        images: [[String: Any]]? = nil,
        onEvent: @escaping SSEEventHandler,
        onComplete: @escaping CompletionHandler
    ) {
        isStreaming = true
        receivedData = Data()
        buffer = ""  // 重置缓冲区
        onEventHandler = onEvent
        onCompleteHandler = onComplete

        // 根据助手类型确定URL
        let endpoint: String
        switch assistant.action {
        case .ask:
            endpoint = "ask"
        case .continueWriting:
            endpoint = "continue"
        case .chat:
            endpoint = "completions"
        }
        let url = URL(string: "\(AppConfig.apiBaseURL)/v1/chat/\(endpoint)")!

        // 构建 OpenAI 格式的 messages 数组
        var messagesArray: [[String: Any]] = []

        // 添加历史消息
        for msg in history {
            messagesArray.append([
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content,
            ])
        }

        // 添加当前消息
        messagesArray.append([
            "role": "user",
            "content": message,
        ])

        // 从配置读取开关（如果没有设置过，使用默认值）
        let userEnableSearch =
            UserDefaults.standard.object(forKey: AppConfig.Keys.enableGoogleSearch) as? Bool
            ?? AppConfig.DefaultValues.enableGoogleSearch
        let userEnableTools =
            UserDefaults.standard.object(forKey: AppConfig.Keys.enableMCPTools) as? Bool
            ?? AppConfig.DefaultValues.enableMCPTools

        let capabilityMode = resolveCapabilityMode(
            message: message,
            preferSearch: userEnableSearch,
            preferTools: userEnableTools
        )
        let enableSearch = capabilityMode.search
        let enableTools = capabilityMode.tools
        let clientToolNames = capabilityMode.clientToolNames

        // ✅ 互斥检查（Gemini 不支持同时使用）
        // （已在 resolveCapabilityMode 中完成）

        // 构建统一的请求体（OpenAI 格式 + 扩展字段）
        var body: [String: Any] = [
            "messages": messagesArray,
            "chat_id": UUID().uuidString,
            "search": enableSearch,  // ✅ 从配置读取
            "tools": enableTools,  // ✅ 从配置读取
            "client_tools": enableTools,
            "client_tool_names": clientToolNames,
            "rag": enableRag,
            "model": model,
            "assistant_id": assistant.id,
            "language": Locale.current.language.languageCode?.identifier ?? "en",  // 传递当前语言
        ]

        // 添加摘要（如果有）
        if let summary = summary {
            body["summary"] = summary
        }

        // 添加图片数据（如果有）
        if let images = images, !images.isEmpty {
            body["images"] = images
            Logger.info("📎 添加 \(images.count) 张图片到请求")
        }

        // ✅ 使用 HTTPClient 创建 SSE 流式请求
        let task = HTTPClient.shared.streamingPost("/v1/chat/\(endpoint)", body: body, delegate: self)

        // 🐛 调试：打印发送的请求数据
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📤 发送聊天请求到后端")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🌐 URL: \(url.absoluteString)")
        print("🔑 API Key: \(AppConfig.apiKey.prefix(20))...")
        print("🤖 Assistant ID: \(assistant.id)")
        print("📋 Assistant Name: \(assistant.name)")
        print("🎯 Action: \(assistant.action)")
        print("🎯 Model: \(model)")
        print("📦 Request Body:")
        if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            print(jsonString)
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // 保存并启动 task
        currentTask = task
        task.resume()
    }

    func submitToolResult(requestId: String, results: [[String: Any]]) async {
        let body: [String: Any] = [
            "request_id": requestId,
            "results": results,
        ]

        Logger.info("📡 提交 tool_result: request_id=\(requestId), items=\(results.count)")

        do {
            let (_, response) = try await HTTPClient.shared.post("/v1/chat/tool-result", body: body)
            if response.statusCode < 200 || response.statusCode >= 300 {
                Logger.error("❌ submitToolResult failed, status=\(response.statusCode)")
            } else {
                Logger.info("✅ submitToolResult ok: request_id=\(requestId), status=\(response.statusCode)")
            }
        } catch {
            Logger.error("❌ submitToolResult error: \(error.localizedDescription)")
        }
    }

    private func resolveCapabilityMode(
        message: String,
        preferSearch: Bool,
        preferTools: Bool
    ) -> (search: Bool, tools: Bool, clientToolNames: [String]) {
        if AppConfig.WidgetToolIntent.shouldUseWidgetTool(message: message) {
            Logger.info("🔧 命中 run_widget 意图，切换为 tools 模式（search 关闭）")
            return (search: false, tools: true, clientToolNames: AppConfig.WidgetToolIntent.clientToolNames)
        }

        if preferSearch && preferTools {
            return (search: false, tools: true, clientToolNames: AppConfig.WidgetToolIntent.clientToolNames)
        }

        return (
            search: preferSearch,
            tools: preferTools,
            clientToolNames: AppConfig.WidgetToolIntent.clientToolNames
        )
    }

    // 停止流式响应
    func stopStreaming() {
        currentTask?.cancel()
        currentTask = nil
        isStreaming = false
        buffer = ""  // 清空缓冲区
    }

    // 解析 SSE 数据（带缓冲区，避免数据丢失）
    private func parseSSEData(onEvent: @escaping SSEEventHandler) {
        let lines = buffer.components(separatedBy: "\n")
        var currentEvent: String?
        var dataLines: [String] = []
        var processedLines = 0

        for (index, line) in lines.enumerated() {
            if line.hasPrefix("event: ") {
                currentEvent = String(line.dropFirst(7))
                dataLines = []
            } else if line.hasPrefix("data: ") {
                dataLines.append(String(line.dropFirst(6)))
            } else if line.isEmpty && currentEvent != nil && !dataLines.isEmpty {
                let eventData = dataLines.joined(separator: "\n")

                if let event = SSEEvent.parse(type: currentEvent!, data: eventData) {
                    DispatchQueue.main.async {
                        onEvent(event)
                    }
                }

                currentEvent = nil
                dataLines = []
                processedLines = index + 1
            }
        }

        // 保留未处理完的数据在缓冲区
        if processedLines > 0 && processedLines < lines.count {
            buffer = lines[processedLines...].joined(separator: "\n")
        } else if processedLines == 0 {
            // 如果没有处理任何完整事件，保留所有数据
            // buffer 保持不变
        } else {
            // 所有数据都已处理
            buffer = ""
        }
    }
}

// MARK: - URLSessionDataDelegate
extension StreamingChatService: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 每次收到数据块就累积到缓冲区
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text

        // 解析缓冲区中的完整事件
        if let onEvent = onEventHandler {
            parseSSEData(onEvent: onEvent)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isStreaming = false
            self.currentTask = nil

            if let error = error {
                self.onCompleteHandler?(.failure(error))
            } else {
                self.onCompleteHandler?(.success(()))
            }

            // 清理
            self.onEventHandler = nil
            self.onCompleteHandler = nil
            self.receivedData = Data()
            self.buffer = ""
        }

        // 注意：HTTPClient.streamingPost 已处理 session 创建
    }
}
