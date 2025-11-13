//
//  RQNetworkManager.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 用类型擦除包装 continuation
private struct PendingRequest {
    let request: any RQNetworkRequest
    let resume: (Result<Any, Error>) -> Void
}

/// 公共 headers/query 动态回调类型
public typealias RQHeadersProvider = () -> [String: String]
public typealias RQQueryParametersProvider = () -> [String: String]

/// 网络管理器
/// 集成 token 刷新队列化、请求拦截器、响应拦截器、动态 headers/query
public final class RQNetworkManager {
    
    public static let shared = RQNetworkManager()
    private init() {}
    
    // MARK: - 动态公共 headers/query
    public var commonHeadersProvider: RQHeadersProvider?
    public var commonQueryParametersProvider: RQQueryParametersProvider?
    
    // MARK: - 拦截器
    public var interceptors: [RQRequestInterceptor] = []
    public var responseInterceptors: [RQResponseInterceptor] = []
    
    // MARK: - 日志 & token刷新
    public var logEnabled: Bool = true
    public var refreshTokenHandler: (() async throws -> Void)?
    
    // MARK: - Token刷新队列
    private var isRefreshingToken = false
    private var pendingRequests: [PendingRequest] = []
    
    private let urlSession = URLSession.shared
    
    /// 可配置 token 过期判断回调
    public var tokenExpiredHandler: ((HTTPURLResponse, Data?) -> Bool)?
    
    // MARK: - 泛型请求
    @discardableResult
    public func request<T: Decodable>(_ request: RQNetworkRequest, responseType: T.Type) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result: T = try await send(request: request, responseType: responseType)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 发送请求
    private func send<T: Decodable>(request: RQNetworkRequest, responseType: T.Type) async throws -> T {
        var urlRequest = try buildURLRequest(request)
        
        // 请求前拦截器 adapt
        for interceptor in interceptors {
            urlRequest = try await interceptor.adapt(urlRequest)
        }
        
        do {
            let (data, response) = try await urlSession.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else { throw RQNetworkError.invalidResponse }
            
            // 判断 token 是否过期
            if let handler = tokenExpiredHandler, handler(httpResponse, data), request.requiresAuth {
                return try await handleAuthFailure(request: request, responseType: responseType)
            }
            
            guard 200..<300 ~= httpResponse.statusCode else {
                throw RQNetworkError.statusCode(httpResponse.statusCode)
            }
            
            let decoded = try JSONDecoder().decode(T.self, from: data)
            
            // 响应拦截器
            for respInterceptor in responseInterceptors {
                await respInterceptor.intercept(data: data, response: response, error: nil)
            }
            
            return decoded
        } catch {
            for respInterceptor in responseInterceptors {
                await respInterceptor.intercept(data: nil, response: nil, error: error)
            }
            throw error
        }
    }
    
    // MARK: - token刷新队列化
    private func handleAuthFailure<T: Decodable>(request: RQNetworkRequest, responseType: T.Type) async throws -> T {
        guard request.requiresAuth else { throw RQNetworkError.tokenExpired }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            // 存储时包装 continuation
            let wrapped = PendingRequest(
                request: request,
                resume: { result in
                    switch result {
                    case .success(let value):
                        if let typed = value as? T {
                            continuation.resume(returning: typed)
                        } else {
                            continuation.resume(throwing: RQNetworkError.invalidResponse)
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            )
            pendingRequests.append(wrapped)
            
            Task {
                if !isRefreshingToken {
                    isRefreshingToken = true
                    do {
                        try await refreshTokenHandler?()
                        isRefreshingToken = false

                        // token 刷新成功，重试所有请求
                        let queued = pendingRequests
                        pendingRequests.removeAll()
                        
                        for item in queued {
                            Task {
                                do {
                                    let result: Any = try await send(request: item.request, responseType: T.self)
                                    item.resume(.success(result))
                                } catch {
                                    item.resume(.failure(error))
                                }
                            }
                        }
                    } catch {
                        isRefreshingToken = false
                        let queued = pendingRequests
                        pendingRequests.removeAll()
                        for item in queued {
                            item.resume(.failure(error))
                        }
                    }
                }
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
        
        var allHeaders = commonHeadersProvider?() ?? [:]
        if let headers = request.headers {
            allHeaders.merge(headers) { $1 }
        }
        urlRequest.allHTTPHeaderFields = allHeaders
        urlRequest.httpBody = request.body
        
        return urlRequest
    }
}

