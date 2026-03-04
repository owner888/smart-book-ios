// SSEEvent.swift - SSE 事件类型定义
// 定义服务器发送事件（Server-Sent Events）的事件类型

import Foundation

/// 工具调用信息
struct ToolInfo: Codable {
    let name: String
    let success: Bool
}

struct ToolCallRequest {
    let requestId: String
    let calls: [[String: Any]]
}

struct ToolAckInfo: Codable {
    let requestId: String
    let round: Int
    let callsCount: Int

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case round
        case callsCount = "calls_count"
    }
}

struct ToolProgressInfo: Codable {
    let requestId: String
    let status: String
    let elapsedSec: Int
    let timeoutSec: Int

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case status
        case elapsedSec = "elapsed_sec"
        case timeoutSec = "timeout_sec"
    }
}

/// SSE 事件类型
enum SSEEvent {
    case systemPrompt(String)
    case thinking(String)
    case content(String)
    case sources([RAGSource])
    case tools([ToolInfo])
    case toolAck(ToolAckInfo)
    case toolProgress(ToolProgressInfo)
    case toolCall(ToolCallRequest)
    case usage(UsageInfo)
    case cached(Bool)
    case error(String)
    case done

    /// 从 SSE 事件类型和数据解析事件
    /// - Parameters:
    ///   - type: 事件类型（如 "content", "usage" 等）
    ///   - data: 事件数据
    /// - Returns: 解析后的 SSEEvent，如果无法解析则返回 nil
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
                let sources = try? JSONDecoder().decode([RAGSource].self, from: jsonData)
            {
                return .sources(sources)
            }
            return nil

        case "tools":
            if let jsonData = data.data(using: .utf8),
                let tools = try? JSONDecoder().decode([ToolInfo].self, from: jsonData)
            {
                return .tools(tools)
            }
            return nil

        case "tool_ack":
            if let jsonData = data.data(using: .utf8),
                let ack = try? JSONDecoder().decode(ToolAckInfo.self, from: jsonData)
            {
                return .toolAck(ack)
            }
            return nil

        case "tool_progress":
            if let jsonData = data.data(using: .utf8),
                let progress = try? JSONDecoder().decode(ToolProgressInfo.self, from: jsonData)
            {
                return .toolProgress(progress)
            }
            return nil

        case "tool_call":
            guard let jsonData = data.data(using: .utf8) else { return nil }
            guard let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }
            guard let requestId = obj["request_id"] as? String else { return nil }
            guard let calls = obj["calls"] as? [[String: Any]] else { return nil }
            return .toolCall(ToolCallRequest(requestId: requestId, calls: calls))

        case "usage":
            if let jsonData = data.data(using: .utf8),
                let usage = try? JSONDecoder().decode(UsageInfo.self, from: jsonData)
            {
                return .usage(usage)
            }
            return nil

        case "cached":
            if let jsonData = data.data(using: .utf8),
                let cacheInfo = try? JSONDecoder().decode([String: Bool].self, from: jsonData),
                let hit = cacheInfo["hit"]
            {
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
