//
//  RQNetworkManager.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

// MARK: - RQNetworkManager

public final class RQNetworkManager: @unchecked Sendable {
    
    public static let shared = RQNetworkManager()
    private init() {}
    
    private let urlSession = URLSession.shared
    
    // MARK: - 超时设置
    public var defaultTimeoutInterval: TimeInterval = 60.0 // 默认超时时间
    
    // MARK: - 重试配置
    private let retryManager = RQRetryManager()
    // 全局默认重试配置（nil 表示不重试）
    public var defaultRetryConfiguration: RQRetryConfiguration? = .default
    
    // MARK: - 拦截器 & 公共 headers/query
    public var interceptors: [RQRequestInterceptor] = []
    public var responseInterceptors: [RQResponseInterceptor] = []
    public var commonHeadersProvider: (@Sendable () -> [String: String])?
    public var commonQueryParametersProvider: (@Sendable () -> [String: String])?
    
    // MARK: - 日志 & token刷新
    public var logEnabled: Bool = true
    public var refreshTokenHandler: (@Sendable () async throws -> Void)?
    public var tokenExpiredHandler: (@Sendable (HTTPURLResponse, Data?) -> Bool)?
    
    // MARK: - Token 刷新状态管理
    
    private let tokenRefreshQueue = DispatchQueue(label: "com.RQNetwork.tokenRefreshQueue")

    private var _isRefreshingToken = false
    private var isRefreshingToken: Bool {
        get {
            tokenRefreshQueue.sync { _isRefreshingToken }
        }
        set {
            tokenRefreshQueue.sync { _isRefreshingToken = newValue }
        }
    }
     
    
    private var refreshContinuations: [CheckedContinuation<Bool, Error>] = []
    
    
    // MARK: - 发送请求
    @discardableResult
    public func send<T: Decodable>(_ request: RQNetworkRequest) async throws -> T {
        // ---- mock 逻辑 ----
        if request.useMock {
            if let data = request.mockResponse {
                return try JSONDecoder().decode(T.self, from: data)
            } else if let name = request.mockFileName,
                      let data = loadMockData(from: name) {
                return try JSONDecoder().decode(T.self, from: data)
            } else {
                throw RQNetworkError.mockDataNotFound
            }
        }
        
        // ---- 构建真实请求 ----
        var urlRequest = try buildURLRequest(request)
        
        // 请求拦截器 adapt
        for interceptor in interceptors {
            urlRequest = try await interceptor.adapt(urlRequest)
        }
        
        do {
            return try await performRequest(request, urlRequest: urlRequest)
        } catch RQNetworkError.tokenExpired {
            
            try await handleAuthFailure()
               
            return try await send(request)
            
        } catch {
            for respInterceptor in responseInterceptors {
                await respInterceptor.intercept(data: nil, response: nil, error: error)
            }
            throw error
        }
    }
    
    // MARK: - 核心请求方法（内部使用）
    private func performRequest<T: Decodable>(_ request: RQNetworkRequest, urlRequest: URLRequest) async throws -> T {
        
        // 统一使用重试管理器执行请求
        return try await retryManager.executeWithRetry(
            request: request,
            urlRequest: urlRequest,
            urlSession: urlSession,
            responseInterceptors: responseInterceptors,
            tokenExpiredHandler: tokenExpiredHandler,
            requiresAuth: request.requiresAuth,
            defaultRetryConfig: defaultRetryConfiguration,
            networkManager: self
        )
    }
    
    // MARK: - 统一的认证失败处理方法
    /// 处理认证失败，统一进行 Token 刷新
    /// - Returns: 刷新成功返回 true，失败抛出错误
    @discardableResult
    public func handleAuthFailure() async throws -> Bool {
        // 如果没有设置刷新处理器，直接抛出错误
        guard refreshTokenHandler != nil else {
            throw RQNetworkError.requestFailed(NSError(
                domain: "RQNetwork",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No refresh token handler set"]
            ))
        }
        
        // 如果已经在刷新中，等待当前刷新完成
        if isRefreshingToken {
            return try await waitForTokenRefresh()
        }
        
        // 开始新的刷新流程
        return try await performTokenRefresh()
    }
        
    /// 执行 Token 刷新
    private func performTokenRefresh() async throws -> Bool {
        isRefreshingToken = true
        defer {
            tokenRefreshQueue.async {[weak self] in
                self?.isRefreshingToken = false
                self?.refreshContinuations.removeAll() // 同步清空数组
            }
        }
        
        do {
            // 执行实际的 Token 刷新
            try await refreshTokenHandler?()
            
            // 同步遍历并唤醒所有续体
            tokenRefreshQueue.async {[weak self] in
                guard let self = self else { return }
                for continuation in self.refreshContinuations {
                    continuation.resume(returning: true)
                }
            }
            
            return true
            
        } catch {
            // 通知所有等待的请求刷新失败
            tokenRefreshQueue.async {[weak self] in
                guard let self = self else { return }
                for continuation in self.refreshContinuations {
                    continuation.resume(throwing: error)
                }
            }
            throw error
        }
    }
    
    /// 等待正在进行的 Token 刷新完成
    private func waitForTokenRefresh() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            tokenRefreshQueue.async {[weak self] in
                self?.refreshContinuations.append(continuation)
            }
        }
    }
    
    
    
    // MARK: - 构建 URLRequest
    private func buildURLRequest(_ request: RQNetworkRequest) throws -> URLRequest {
        guard let baseURL = RQDomainManager.shared.getDomain(request.domainKey) else {
            throw RQNetworkError.invalidURL
        }
        guard var urlComponents = URLComponents(string: baseURL + request.path) else {
            throw RQNetworkError.invalidURL
        }
        
        var allQuery = commonQueryParametersProvider?() ?? [:]
        if let query = request.queryParameters {
            allQuery.merge(query) { $1 }
        }
        if !allQuery.isEmpty {
            urlComponents.queryItems = allQuery.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents.url else { throw RQNetworkError.invalidURL }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        
        // 设置超时时间
        if let customTimeout = request.timeoutInterval {
            urlRequest.timeoutInterval = customTimeout
        } else {
            urlRequest.timeoutInterval = defaultTimeoutInterval
        }
        
        var allHeaders = commonHeadersProvider?() ?? [:]
        if let headers = request.headers {
            allHeaders.merge(headers) { $1 }
        }
        urlRequest.allHTTPHeaderFields = allHeaders
        urlRequest.httpBody = request.body
        
        return urlRequest
    }
    
    // MARK: - loadMockData（根 bundle）
    private func loadMockData(from fileName: String) -> Data? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}

// MARK: - 文件上传扩展
public extension RQNetworkManager {
    
    /// 上传文件（统一使用 handleAuthFailure 处理 token 过期）
    @discardableResult
    func upload<T: Decodable>(
        _ request: RQFileUploadRequest,
        progressHandler: RQUploadProgressHandler? = nil
    ) async throws -> RQUploadResponse<T> {
        
        // 构建 multipart 请求
        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = try buildURLRequest(request)
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try buildMultipartBody(for: request, boundary: boundary)
        
        // 请求拦截器 adapt
        for interceptor in interceptors {
            urlRequest = try await interceptor.adapt(urlRequest)
        }
        
        // 统一使用 performRequest，自动处理 token 过期
        do {
            let response: T = try await performRequest(request, urlRequest: urlRequest)
            
            let uploadResponse = RQUploadResponse(
                response: response,
                totalBytesSent: Int64(urlRequest.httpBody?.count ?? 0),
                totalBytesExpectedToSend: Int64(urlRequest.httpBody?.count ?? 0)
            )
            
            return uploadResponse
            
        } catch RQNetworkError.tokenExpired {
            // Token 过期，使用统一的认证处理方法
            guard request.requiresAuth else {
                throw RQNetworkError.tokenExpired
            }
            
            // 🔧 等待 Token 刷新完成
            _ = try await handleAuthFailure()
            
            // 🔧 刷新成功后重新发起上传
            let response: T = try await performRequest(request, urlRequest: urlRequest)
            
            let uploadResponse = RQUploadResponse(
                response: response,
                totalBytesSent: Int64(urlRequest.httpBody?.count ?? 0),
                totalBytesExpectedToSend: Int64(urlRequest.httpBody?.count ?? 0)
            )
            
            return uploadResponse
        }
    }
    
    private func buildMultipartBody(for request: RQFileUploadRequest, boundary: String) throws -> Data {
        var body = Data()
        
        // 添加表单字段
        if let formFields = request.formFields {
            for (key, value) in formFields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        
        // 添加文件
        for file in request.files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // 结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}


// MARK: - 文件下载扩展
public extension RQNetworkManager {
    
    /// 下载文件（统一使用 handleAuthFailure 处理 token 过期）
    func download(
        _ request: RQNetworkRequest,
        to destination: RQDownloadDestination,
        progressHandler: RQDownloadProgressHandler? = nil
    ) async throws -> RQDownloadResponse {
        
        // 构建 URLRequest
        var urlRequest = try buildURLRequest(request)
        
        // 请求拦截器 adapt
        for interceptor in interceptors {
            urlRequest = try await interceptor.adapt(urlRequest)
        }
        
        let destinationURL = destination.makeURL()
        let requireAuth = request.requiresAuth
        // 使用 URLSession 的下载任务，但统一处理 token 过期
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.downloadTask(with: urlRequest) {[weak self] tempURL, response, error in
                guard let self = self else {
                    return
                }
                
                Task {
                    do {
                        if let error = error {
                            throw error
                        }
                        
                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw RQNetworkError.invalidResponse
                        }
                        
                        // Token 过期处理 - 统一抛出 tokenExpired 错误
                        if let handler = self.tokenExpiredHandler,
                           handler(httpResponse, nil),
                           requireAuth {
                            throw RQNetworkError.tokenExpired
                        }
                        
                        guard 200..<300 ~= httpResponse.statusCode else {
                            throw RQNetworkError.statusCode(httpResponse.statusCode)
                        }
                        
                        guard let tempURL = tempURL else {
                            throw RQNetworkError.invalidResponse
                        }
                        
                        // 移动文件到目标位置
                        try? FileManager.default.removeItem(at: destinationURL)
                        try FileManager.default.copyItem(at: tempURL, to: destinationURL)
                        
                        // 获取文件大小信息
                        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        
                        let downloadResponse = RQDownloadResponse(
                            localURL: destinationURL,
                            totalBytesReceived: fileSize,
                            totalBytesExpectedToReceive: fileSize
                        )
                        
                        // 响应拦截器
                        for respInterceptor in self.responseInterceptors {
                            await respInterceptor.intercept(data: nil, response: response, error: nil)
                        }
                        
                        continuation.resume(returning: downloadResponse)
                        
                    } catch RQNetworkError.tokenExpired {
                        
                        // Token 过期，使用统一的认证处理方法
                        Task {
                            do {
                                guard requireAuth else {
                                    continuation.resume(throwing: RQNetworkError.tokenExpired)
                                    return
                                }
                                
                                // 🔧 等待 Token 刷新完成
                                _ = try await self.handleAuthFailure()
                                
                                // 🔧 刷新成功后重新发起下载
                                let newResponse = try await self.download(request, to: destination)
                                continuation.resume(returning: newResponse)
                                
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } catch {
                        // 响应拦截器 - 错误情况
                        for respInterceptor in self.responseInterceptors {
                            await respInterceptor.intercept(data: nil, response: response, error: error)
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            task.resume()
        }
    }
    
    
    /// 恢复下载（支持断点续传）
    func resumeDownload(
        from resumeData: Data,
        to destination: RQDownloadDestination,
        progressHandler: RQDownloadProgressHandler? = nil
    ) async throws -> RQDownloadResponse {
        
        let destinationURL = destination.makeURL()
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.downloadTask(withResumeData: resumeData) { tempURL, response, error in
                Task {
                    do {
                        if let error = error {
                            throw error
                        }
                        
                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw RQNetworkError.invalidResponse
                        }
                        
                        // Token 过期处理
                        if let handler = self.tokenExpiredHandler,
                           handler(httpResponse, nil) {
                            // 对于恢复下载，直接抛出错误，让调用方处理
                            throw RQNetworkError.tokenExpired
                        }
                        
                        guard 200..<300 ~= httpResponse.statusCode else {
                            throw RQNetworkError.statusCode(httpResponse.statusCode)
                        }
                        
                        guard let tempURL = tempURL else {
                            throw RQNetworkError.invalidResponse
                        }
                        
                        // 移动文件到目标位置
                        try? FileManager.default.removeItem(at: destinationURL)
                        try FileManager.default.copyItem(at: tempURL, to: destinationURL)
                        
                        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        
                        let downloadResponse = RQDownloadResponse(
                            localURL: destinationURL,
                            totalBytesReceived: fileSize,
                            totalBytesExpectedToReceive: fileSize
                        )
                        
                        // 响应拦截器
                        for respInterceptor in self.responseInterceptors {
                            await respInterceptor.intercept(data: nil, response: response, error: nil)
                        }
                        
                        continuation.resume(returning: downloadResponse)
                        
                    } catch {
                        // 响应拦截器 - 错误情况
                        for respInterceptor in self.responseInterceptors {
                            await respInterceptor.intercept(data: nil, response: response, error: error)
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            task.resume()
        }
    }
}

// MARK: - SSE 扩展
public extension RQNetworkManager {
    
    /// 创建 SSE 客户端
    func createSSEClient() -> RQSSEClient {
        
        return RQSSEClient(urlSession: urlSession)
    }
    
    
    
    /// 连接到 SSE 流
    func connectToSSE(_ request: RQSSERequest) throws -> RQSSEClient {
        let client = createSSEClient()
        try client.connect(with: request)
        return client
    }
}

