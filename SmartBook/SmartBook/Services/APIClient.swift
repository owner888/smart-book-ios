// APIClient.swift - API 请求客户端
// 封装通用的 API 请求配置（JSON、Authorization、超时等）

import Foundation

/// HTTP 请求方法
enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
}

/// API 客户端
/// 提供统一的 API 请求方法，自动处理通用配置
class APIClient {
    
    // MARK: - 单例
    
    static let shared = APIClient()
    
    private init() {}
    
    // MARK: - 配置
    
    /// 默认超时时间
    private let defaultTimeout: TimeInterval = 30
    
    /// 长请求超时时间（如上传）
    private let longTimeout: TimeInterval = 300
    
    // MARK: - 请求方法
    
    /// 发送 GET 请求
    func get(_ endpoint: String, timeout: TimeInterval? = nil) async throws -> (Data, HTTPURLResponse) {
        try await request(endpoint, method: .GET, timeout: timeout)
    }
    
    /// 发送 POST 请求
    func post(_ endpoint: String, body: [String: Any]? = nil, timeout: TimeInterval? = nil) async throws -> (Data, HTTPURLResponse) {
        try await request(endpoint, method: .POST, body: body, timeout: timeout)
    }
    
    /// 发送 PUT 请求
    func put(_ endpoint: String, body: [String: Any]? = nil, timeout: TimeInterval? = nil) async throws -> (Data, HTTPURLResponse) {
        try await request(endpoint, method: .PUT, body: body, timeout: timeout)
    }
    
    /// 发送 DELETE 请求
    func delete(_ endpoint: String, timeout: TimeInterval? = nil) async throws -> (Data, HTTPURLResponse) {
        try await request(endpoint, method: .DELETE, timeout: timeout)
    }
    
    // MARK: - 核心请求方法
    
    /// 通用请求方法
    /// - Parameters:
    ///   - endpoint: API 端点（如 "/api/books"）
    ///   - method: HTTP 方法
    ///   - body: 请求体（可选）
    ///   - timeout: 超时时间（可选，默认30秒）
    ///   - includeAuth: 是否包含 Authorization header（默认 true）
    /// - Returns: (Data, HTTPURLResponse) 元组
    private func request(
        _ endpoint: String,
        method: HTTPMethod,
        body: [String: Any]? = nil,
        timeout: TimeInterval? = nil,
        includeAuth: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        
        // 构建完整 URL
        let urlString = endpoint.hasPrefix("http") ? endpoint : "\(AppConfig.apiBaseURL)\(endpoint)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidRequest
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeout ?? defaultTimeout
        
        // ✅ 统一设置通用 headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // ✅ 自动添加 Authorization header
        if includeAuth {
            request.setValue("Bearer \(AppConfig.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // 添加请求体（如果有）
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查响应类型
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        return (data, httpResponse)
    }
    
    // MARK: - 上传方法
    
    /// 上传文件
    /// - Parameters:
    ///   - endpoint: API 端点
    ///   - fileData: 文件数据
    ///   - filename: 文件名
    ///   - fieldName: 表单字段名（默认 "file"）
    ///   - onProgress: 进度回调
    /// - Returns: (Data, HTTPURLResponse)
    func upload(
        _ endpoint: String,
        fileData: Data,
        filename: String,
        fieldName: String = "file",
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        
        let urlString = "\(AppConfig.apiBaseURL)\(endpoint)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidRequest
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = longTimeout
        
        // ✅ 添加 Authorization header
        request.setValue("Bearer \(AppConfig.apiKey)", forHTTPHeaderField: "Authorization")
        
        // 创建 multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 创建自定义 URLSession 用于进度跟踪
        let configuration = URLSessionConfiguration.default
        let delegate = UploadProgressDelegate(onProgress: onProgress)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        
        let (data, response) = try await session.upload(for: request, from: body)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        return (data, httpResponse)
    }
    
    // MARK: - 辅助方法
    
    /// 解码 JSON 响应
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.parseError
        }
    }
}

// MARK: - 上传进度代理（从 BookService 移过来）
private class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let onProgress: ((Double) -> Void)?
    
    init(onProgress: ((Double) -> Void)?) {
        self.onProgress = onProgress
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.onProgress?(progress)
        }
    }
}
