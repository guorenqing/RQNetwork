//
//  RQSSE.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// SSE 事件
public struct RQSSEEvent: Sendable {
    public let id: String?
    public let event: String?
    public let data: String?
    public let retry: Int?
    public let timestamp: Date
    
    public init(id: String?, event: String?, data: String?, retry: Int?) {
        self.id = id
        self.event = event
        self.data = data
        self.retry = retry
        self.timestamp = Date()
    }
}

/// SSE 事件处理器
public protocol RQSSEEventHandler: AnyObject,Sendable {
    /// 接收到事件
    func didReceiveEvent(_ event: RQSSEEvent)
    
    /// 连接状态改变
    func connectionStateDidChange(_ isConnected: Bool)
    
    /// 发生错误
    func didReceiveError(_ error: Error)
}

/// SSE 请求协议
public protocol RQSSERequest: RQNetworkRequest {
    /// SSE 事件处理器
    var eventHandler: RQSSEEventHandler { get }
    
    /// 自动重连配置
    var autoReconnect: RQSSEAutoReconnectConfig { get }
}

/// SSE 自动重连配置
public struct RQSSEAutoReconnectConfig: Sendable {
    public let maxRetryCount: Int
    public let retryDelay: TimeInterval
    public let enable: Bool
    
    public init(maxRetryCount: Int = 3, retryDelay: TimeInterval = 2.0, enable: Bool = true) {
        self.maxRetryCount = maxRetryCount
        self.retryDelay = retryDelay
        self.enable = enable
    }
    
    public static let `default` = RQSSEAutoReconnectConfig()
    public static let disabled = RQSSEAutoReconnectConfig(enable: false)
}

// MARK: - 默认实现
public extension RQSSERequest {
    /// 默认需要权限验证
        var requiresAuth: Bool { true }
        
        /// 默认不使用 mock（SSE 不支持 Mock）
        var useMock: Bool { false }
        
        /// 默认开启自动重连
        var autoReconnect: RQSSEAutoReconnectConfig { .default }
        
        /// 默认使用 GET 方法，但可以重写为 POST
        var method: RQHTTPMethod { .GET }
        
        /// SSE 默认使用较长的超时时间
        var timeoutInterval: TimeInterval? { 300.0 }
}

/// SSE 客户端
public final class RQSSEClient: @unchecked Sendable {
    
    private var _task: URLSessionDataTask?
    private var task: URLSessionDataTask? {
        get { stateQueue.sync { _task } }    // 同步读取
        set { stateQueue.sync { _task = newValue } }  // 同步写入
    }
    private let urlSession: URLSession
    /// 全局默认超时时间（SSE 长连接建议设置较大值，如 300 秒）
    public static var defaultTimeoutInterval: TimeInterval = 300.0
    /// 当前连接的超时时间（nil 则使用全局默认）
    private var timeoutInterval: TimeInterval?
    private var _timeoutInterval: TimeInterval? {
        get { stateQueue.sync { timeoutInterval } }    // 同步读取
        set { stateQueue.sync { timeoutInterval = newValue } }  // 同步写入
    }

    // 串行队列用于同步所有状态修改
    private let stateQueue = DispatchQueue(label: "com.RQNetwork.sse.state")
    
    // 事件回调
    private weak var _eventHandler: RQSSEEventHandler?
    private weak var eventHandler: RQSSEEventHandler? {
        get { stateQueue.sync { _eventHandler } }
        set { stateQueue.sync { _eventHandler = newValue } }
    }
    
    // 自动重连配置
    private var _autoReconnectConfig: RQSSEAutoReconnectConfig!
    private var autoReconnectConfig: RQSSEAutoReconnectConfig {
        get { stateQueue.sync { _autoReconnectConfig } }
        set { stateQueue.sync { _autoReconnectConfig = newValue } }
    }
    
    // 请求头
    private var _currentHeaders: [String: String] = [:]
    private var currentHeaders: [String: String] {
        get { stateQueue.sync { _currentHeaders } }
        set { stateQueue.sync { _currentHeaders = newValue } }
    }
    
    // 连接状态
    private var _isConnected = false
    private var isConnected: Bool {
        get { stateQueue.sync { _isConnected } }
        set { stateQueue.sync { _isConnected = newValue } }
    }
    
    // 重连次数
    private var _reconnectAttempts = 0
    private var reconnectAttempts: Int {
        get { stateQueue.sync { _reconnectAttempts } }
        set { stateQueue.sync { _reconnectAttempts = newValue } }
    }
    
    // 当前连接url
    private var _currentURL: URL? = nil
    private var currentURL: URL?
    {
        get { stateQueue.sync { _currentURL } }
        set { stateQueue.sync { _currentURL = newValue } }
    }
    
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.autoReconnectConfig = .default
    }
    
    /// 连接到 SSE 端点
    public func connect(with request: RQSSERequest) throws {
        guard let baseURL = RQDomainManager.shared.getDomain(request.domainKey) else {
            throw RQNetworkError.invalidURL
        }
        
        guard let url = URL(string: baseURL + request.path) else {
            throw RQNetworkError.invalidURL
        }
        
        // 构建请求头
        var headers: [String: String] = [:]
        if let commonHeaders = RQNetworkManager.shared.commonHeadersProvider?() {
            headers.merge(commonHeaders) { $1 }
        }
        if let requestHeaders = request.headers {
            headers.merge(requestHeaders) { $1 }
        }
        
        connect(
            to: url,
            eventHandler: request.eventHandler,
            headers: headers,
            method: request.method,
            body: request.body, // 使用基类的 body
            autoReconnect: request.autoReconnect,
            timeoutInterval: request.timeoutInterval // 使用基类的 timeoutInterval
        )
    }
    
    /// 底层连接方法
    private func connect(
        to url: URL,
        eventHandler: RQSSEEventHandler,
        headers: [String: String] = [:],
        method: RQHTTPMethod = .GET,
        body: Data? = nil,
        autoReconnect: RQSSEAutoReconnectConfig = .default,
        timeoutInterval: TimeInterval? = nil
    ) {
        disconnect()
        
        self.eventHandler = eventHandler
        self.autoReconnectConfig = autoReconnect
        self.currentURL = url
        self.currentHeaders = headers
        self.reconnectAttempts = 0
        self.timeoutInterval = timeoutInterval
        
        performConnect(method: method, body: body)
    }

    
    private func performConnect(method: RQHTTPMethod = .GET, body: Data? = nil) {
        guard let url = currentURL else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = timeoutInterval ?? Self.defaultTimeoutInterval
        
        // 设置请求体（如果是 POST、PUT 等方法）
        if method != .GET, let body = body {
            request.httpBody = body
            // 根据内容类型设置合适的 Content-Type
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        // 添加认证头信息
        for (key, value) in currentHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleError(error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.handleError(RQNetworkError.invalidResponse)
                return
            }
            
            
            // Token 过期处理 - 统一使用 NetworkManager 的刷新机制
            if let handler = RQNetworkManager.shared.tokenExpiredHandler, handler(httpResponse, data) {
                self.handleTokenExpired()
                return
            }
            
            guard 200..<300 ~= httpResponse.statusCode else {
                self.handleError(RQNetworkError.statusCode(httpResponse.statusCode))
                return
            }
            
            self.isConnected = true
            self.reconnectAttempts = 0
            DispatchQueue.main.async {
                self.eventHandler?.connectionStateDidChange(true)
            }
            
            // 这里应该持续读取数据流，解析 SSE 事件
            // 简化实现，实际需要处理数据流解析
        }
        
        task?.resume()
    }
    
    private func handleTokenExpired() {
        DispatchQueue.main.async {
            self.eventHandler?.connectionStateDidChange(false)
        }
        
        Task {
            do {
                // 🔧 使用统一的认证处理方法
                try await RQNetworkManager.shared.handleAuthFailure()
                
                // Token 刷新成功，重新连接
                DispatchQueue.main.async {
                    self.performConnect()
                }
                
            } catch {
                self.handleError(error)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.eventHandler?.didReceiveError(error)
            self.eventHandler?.connectionStateDidChange(false)
        }
        
        // 自动重连逻辑
        if autoReconnectConfig.enable && reconnectAttempts < autoReconnectConfig.maxRetryCount {
            reconnectAttempts += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + autoReconnectConfig.retryDelay) {
                self.performConnect()
            }
        }
    }
    
    /// 断开连接
    public func disconnect() {
        task?.cancel()
        task = nil
        isConnected = false
    }
    
    deinit {
        disconnect()
    }
}
