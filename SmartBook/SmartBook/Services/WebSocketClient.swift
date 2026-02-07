// WebSocketClient.swift - WebSocket 客户端
// 统一管理 WebSocket 连接、重连、心跳等

import Foundation
import Combine

/// WebSocket 消息类型
enum WebSocketMessage {
    case text(String)
    case data(Data)
}

/// WebSocket 客户端
/// 提供统一的 WebSocket 连接管理，自动处理重连、心跳等
class WebSocketClient: NSObject {
    
    // MARK: - 配置
    
    /// 心跳间隔（秒）
    private let heartbeatInterval: TimeInterval = 30
    
    /// 重连延迟上限（秒）
    private let maxReconnectDelay: TimeInterval = 30
    
    /// 最大重连次数（0表示无限重试）
    private let maxReconnectAttempts: Int = 0
    
    // MARK: - 状态
    
    @Published var isConnected = false
    private(set) var reconnectAttempts = 0
    
    // MARK: - WebSocket
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    // MARK: - 定时器
    
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    
    // MARK: - 配置
    
    private let url: URL
    private var shouldAutoReconnect = true
    private var onConnected: (() -> Void)?
    private var onDisconnected: ((Error?) -> Void)?
    private var onMessage: ((WebSocketMessage) -> Void)?
    
    // MARK: - 初始化
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - 连接管理
    
    /// 连接 WebSocket
    /// - Parameters:
    ///   - onConnected: 连接成功回调
    ///   - onDisconnected: 断开连接回调
    ///   - onMessage: 收到消息回调
    func connect(
        onConnected: (() -> Void)? = nil,
        onDisconnected: ((Error?) -> Void)? = nil,
        onMessage: @escaping (WebSocketMessage) -> Void
    ) {
        self.onConnected = onConnected
        self.onDisconnected = onDisconnected
        self.onMessage = onMessage
        
        // 创建 WebSocket 连接
        let session = URLSession(configuration: .default)
        self.session = session
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        
        // 开始接收消息
        receiveMessage()
        
        // 启动心跳
        startHeartbeat()
        
        // 通知连接成功
        onConnected?()
        
        Logger.info("🔌 WebSocket 连接成功: \(url.absoluteString)")
    }
    
    /// 断开连接
    func disconnect() {
        shouldAutoReconnect = false
        
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        isConnected = false
        
        Logger.info("🔌 WebSocket 已断开")
    }
    
    // MARK: - 消息发送
    
    /// 发送文本消息
    func send(text: String) async throws {
        guard let webSocketTask = webSocketTask else {
            throw NSError(domain: "WebSocketClient", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "WebSocket 未连接"
            ])
        }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        try await webSocketTask.send(message)
    }
    
    /// 发送二进制消息
    func send(data: Data) async throws {
        guard let webSocketTask = webSocketTask else {
            throw NSError(domain: "WebSocketClient", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "WebSocket 未连接"
            ])
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        try await webSocketTask.send(message)
    }
    
    /// 发送 JSON 消息
    func send(json: [String: Any]) async throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "WebSocketClient", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "JSON 序列化失败"
            ])
        }
        
        try await send(text: jsonString)
    }
    
    // MARK: - 消息接收
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                // 处理消息
                switch message {
                case .string(let text):
                    self.onMessage?(.text(text))
                case .data(let data):
                    self.onMessage?(.data(data))
                @unknown default:
                    break
                }
                
                // 继续接收下一条消息
                self.receiveMessage()
                
            case .failure(let error):
                Logger.error("WebSocket 接收消息失败: \(error.localizedDescription)")
                
                self.isConnected = false
                self.onDisconnected?(error)
                
                // 尝试重连
                self.attemptReconnect()
            }
        }
    }
    
    // MARK: - 心跳
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            
            Task {
                do {
                    try await self.send(json: ["type": "ping"])
                } catch {
                    Logger.error("发送心跳失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 重连机制
    
    private func attemptReconnect() {
        guard shouldAutoReconnect else {
            Logger.info("自动重连已禁用")
            return
        }
        
        // 检查最大重连次数
        if maxReconnectAttempts > 0 && reconnectAttempts >= maxReconnectAttempts {
            Logger.error("❌ 达到最大重连次数 (\(maxReconnectAttempts))，停止重连")
            return
        }
        
        reconnectAttempts += 1
        
        // 计算延迟时间（指数退避）
        let delay = min(pow(2.0, Double(reconnectAttempts - 1)), maxReconnectDelay)
        
        Logger.info("🔄 WebSocket 将在 \(delay) 秒后重连（第 \(reconnectAttempts) 次）")
        
        reconnectTimer?.invalidate()
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Logger.info("🔄 尝试重新连接 WebSocket...")
            self.connect(
                onConnected: self.onConnected,
                onDisconnected: self.onDisconnected,
                onMessage: self.onMessage ?? { _ in }
            )
            
            if self.isConnected {
                self.reconnectAttempts = 0
                Logger.info("✅ WebSocket 重连成功")
            }
        }
    }
    
    /// 重置重连计数器
    func resetReconnectAttempts() {
        reconnectAttempts = 0
    }
}
