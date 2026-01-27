// AssistantService.swift - 助手配置服务

import Foundation

@Observable
class AssistantService {
    static let shared = AssistantService()

    var assistants: [Assistant]
    var currentAssistant: Assistant
    var isLoading = false

    private init() {
        self.assistants = Assistant.defaultAssistants
        // 默认选中通用聊天（id: "chat"）
        self.currentAssistant =
            Assistant.defaultAssistants.first(where: { $0.id == "chat" }) ?? Assistant.defaultAssistants.first!
    }

    // 加载助手配置（从API）
    func loadAssistants() async throws {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: "\(AppConfig.apiBaseURL)/api/assistants")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw APIError.serverError
        }

        // 解析助手配置（现在是数组格式，保持PHP返回的顺序）
        if let jsonRoot = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let assistantsData = jsonRoot["data"] as? [[String: Any]]
        {
            var loadedAssistants: [Assistant] = []

            for config in assistantsData {
                if let id = config["id"] as? String,
                    let name = config["name"] as? String,
                    let avatar = config["avatar"] as? String,
                    let color = config["color"] as? String,
                    let description = config["description"] as? String,
                    let systemPrompt = config["systemPrompt"] as? String,
                    let actionStr = config["action"] as? String,
                    let action = AssistantAction(rawValue: actionStr)
                {

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
                // 直接使用数组顺序，不需要排序
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
