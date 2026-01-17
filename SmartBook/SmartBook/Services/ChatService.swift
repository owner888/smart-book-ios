// ChatService.swift - 流式聊天服务（支持SSE流式响应）

import Foundation

// MARK: - 流式聊天服务
@Observable
class StreamingChatService {
    var isStreaming = false
    var currentTask: URLSessionDataTask?
    
    // SSE 事件处理闭包
    typealias SSEEventHandler = (SSEEvent) -> Void
    typealias CompletionHandler = (Result<Void, Error>) -> Void
    
    // 发送消息（SSE 流式）
    func sendMessageStream(
        message: String,
        assistant: Assistant,
        bookId: String?,
        model: String = "gemini-2.0-flash-exp",
        ragEnabled: Bool = true,
        onEvent: @escaping SSEEventHandler,
        onComplete: @escaping CompletionHandler
    ) {
        Logger.info("🔵 StreamingChatService: sendMessageStream 被调用")
        Logger.info("📝 消息: \(message)")
        Logger.info("👤 助手: \(assistant.name)")
        Logger.info("📚 书籍ID: \(bookId ?? "无")")
        Logger.info("🤖 模型: \(model)")
        Logger.info("🔍 RAG: \(ragEnabled)")
        
        isStreaming = true
        
        var url: URL
        var body: [String: Any]
        
        switch assistant.action {
        case .ask:
            url = URL(string: "\(AppConfig.apiBaseURL)/api/stream/ask")!
            body = [
                "question": message,
                "chat_id": UUID().uuidString,
                "search": false,
                "rag": ragEnabled,
                "model": model
            ]
            if let bookId = bookId {
                body["book_id"] = bookId
            }
            
        case .continueWriting:
            url = URL(string: "\(AppConfig.apiBaseURL)/api/stream/enhanced-continue")!
            body = [
                "book": bookId ?? "",
                "prompt": message,
                "model": model
            ]
            
        case .chat:
            url = URL(string: "\(AppConfig.apiBaseURL)/api/stream/chat")!
            body = [
                "message": message,
                "chat_id": UUID().uuidString,
                "search": false,
                "model": model
            ]
        }
        
        Logger.info("🌐 请求URL: \(url.absoluteString)")
        Logger.info("📦 请求体: \(body)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300 // 5分钟超时
        
        Logger.info("✅ 请求已构建，准备发送")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            Logger.info("📨 收到响应")
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isStreaming = false
                self.currentTask = nil
            }
            
            if let error = error {
                Logger.error("❌ 请求错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    onComplete(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                Logger.info("📊 HTTP状态码: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                Logger.error("❌ 没有收到数据")
                DispatchQueue.main.async {
                    onComplete(.failure(APIError.custom("No data received")))
                }
                return
            }
            
            Logger.info("📦 收到数据大小: \(data.count) bytes")
            if let responseText = String(data: data, encoding: .utf8) {
                Logger.info("📄 响应内容（前500字符）: \(String(responseText.prefix(500)))")
            }
            
            // 解析 SSE 数据
            Logger.info("🔄 开始解析SSE数据")
            self.parseSSEData(data, onEvent: onEvent)
            
            DispatchQueue.main.async {
                onComplete(.success(()))
            }
        }
        
        currentTask = task
        task.resume()
    }
    
    // 停止流式响应
    func stopStreaming() {
        currentTask?.cancel()
        currentTask = nil
        isStreaming = false
    }
    
    // 解析 SSE 数据
    private func parseSSEData(_ data: Data, onEvent: @escaping SSEEventHandler) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        
        let lines = text.components(separatedBy: "\n")
        var currentEvent: String?
        var dataLines: [String] = []
        
        for line in lines {
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
            }
        }
    }
}

// MARK: - SSE 事件类型
enum SSEEvent {
    case systemPrompt(String)
    case thinking(String)
    case content(String)
    case sources([RAGSource])
    case usage(UsageInfo)
    case cached(Bool)
    case error(String)
    case done
    
    static func parse(type: String, data: String) -> SSEEvent? {
        switch type {
        case "system_prompt":
            return .systemPrompt(data)
            
        case "thinking":
            return .thinking(data)
            
        case "content":
            return .content(data)
            
        case "sources":
            if let jsonData = data.data(using: .utf8),
               let sources = try? JSONDecoder().decode([RAGSource].self, from: jsonData) {
                return .sources(sources)
            }
            return nil
            
        case "usage":
            if let jsonData = data.data(using: .utf8),
               let usage = try? JSONDecoder().decode(UsageInfo.self, from: jsonData) {
                return .usage(usage)
            }
            return nil
            
        case "cached":
            if let jsonData = data.data(using: .utf8),
               let cacheInfo = try? JSONDecoder().decode([String: Bool].self, from: jsonData),
               let hit = cacheInfo["hit"] {
                return .cached(hit)
            }
            return nil
            
        case "error":
            return .error(data)
            
        case "done":
            return .done
            
        default:
            return nil
        }
    }
}

// MARK: - 助手服务
@Observable
class AssistantService {
    var assistants: [Assistant]
    var currentAssistant: Assistant
    var isLoading = false
    
    init() {
        self.assistants = Assistant.defaultAssistants
        self.currentAssistant = Assistant.defaultAssistants.first!
    }
    
    // 加载助手配置（从API）
    func loadAssistants() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let url = URL(string: "\(AppConfig.apiBaseURL)/api/assistants")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        // 解析助手配置
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            var loadedAssistants: [Assistant] = []
            
            for (id, config) in json {
                if let name = config["name"] as? String,
                   let avatar = config["avatar"] as? String,
                   let color = config["color"] as? String,
                   let description = config["description"] as? String,
                   let systemPrompt = config["systemPrompt"] as? String,
                   let actionStr = config["action"] as? String,
                   let action = AssistantAction(rawValue: actionStr) {
                    
                    let useRAG = (config["useRAG"] as? Bool) ?? false
                    
                    let assistant = Assistant(
                        id: id,
                        name: name,
                        avatar: avatar,
                        color: color,
                        description: description,
                        systemPrompt: systemPrompt,
                        action: action,
                        useRAG: useRAG
                    )
                    loadedAssistants.append(assistant)
                }
            }
            
            if !loadedAssistants.isEmpty {
                assistants = loadedAssistants
                if !assistants.contains(where: { $0.id == currentAssistant.id }) {
                    currentAssistant = assistants.first!
                }
            }
        }
    }
    
    // 切换助手
    func switchAssistant(_ assistant: Assistant) {
        currentAssistant = assistant
    }
    
    // 根据ID获取助手
    func getAssistant(id: String) -> Assistant? {
        assistants.first(where: { $0.id == id })
    }
}

// MARK: - 模型服务
@Observable
class ModelService {
    var models: [AIModel]
    var currentModel: AIModel
    var isLoading = false
    
    init() {
        self.models = AIModel.defaultModels
        self.currentModel = AIModel.defaultModels.first!
    }
    
    // 加载模型列表（从API）
    func loadModels() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let url = URL(string: "\(AppConfig.apiBaseURL)/api/models")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // 使用默认模型
                return
            }
            
            if let loadedModels = try? JSONDecoder().decode([AIModel].self, from: data),
               !loadedModels.isEmpty {
                models = loadedModels
                if !models.contains(where: { $0.id == currentModel.id }) {
                    currentModel = models.first!
                }
            }
        } catch {
            // 使用默认模型，不抛出错误
            Logger.error("Failed to load models: \(error)")
        }
    }
    
    // 切换模型
    func switchModel(_ model: AIModel) {
        currentModel = model
    }
    
    // 根据ID获取模型
    func getModel(id: String) -> AIModel? {
        models.first(where: { $0.id == id })
    }
}
