//
//  RQNetworkManager.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

// MARK: - PendingRequest 类型擦除

private protocol PendingRequestType {
    var request: any RQNetworkRequest { get }
    func resumeAny(with result: Result<Any, Error>)
}

private struct PendingRequest<T: Decodable>: PendingRequestType {
    let request: any RQNetworkRequest
    let resume: (Result<T, Error>) -> Void
    
    func resumeAny(with result: Result<Any, Error>) {
        switch result {
        case .success(let value):
            if let typed = value as? T {
                resume(.success(typed))
            } else {
                resume(.failure(RQNetworkError.invalidResponse))
            }
        case .failure(let error):
            resume(.failure(error))
        }
    }
}

// MARK: - RQNetworkManager

public final class RQNetworkManager {
    
    public static let shared = RQNetworkManager()
    private init() {}
    
    private let urlSession = URLSession.shared
    
    // MARK: - 拦截器 & 公共 headers/query
    public var interceptors: [RQRequestInterceptor] = []
    public var responseInterceptors: [RQResponseInterceptor] = []
    public var commonHeadersProvider: (() -> [String: String])?
    public var commonQueryParametersProvider: (() -> [String: String])?
    
    // MARK: - 日志 & token刷新
    public var logEnabled: Bool = true
    public var refreshTokenHandler: (() async throws -> Void)?
    public var tokenExpiredHandler: ((HTTPURLResponse, Data?) -> Bool)?
    
    // MARK: - token刷新队列
    private var isRefreshingToken = false
    private var pendingRequests: [PendingRequestType] = []
    
    
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
            let (data, response) = try await urlSession.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else { throw RQNetworkError.invalidResponse }
            
            // token过期处理
            if let handler = tokenExpiredHandler, handler(httpResponse, data), request.requiresAuth {
                return try await handleAuthFailure(request: request)
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
    private func handleAuthFailure<T: Decodable>(request: RQNetworkRequest) async throws -> T {
        guard request.requiresAuth else { throw RQNetworkError.tokenExpired }
        
        return try await withCheckedThrowingContinuation { continuation in
            let wrapped = PendingRequest<T>(
                request: request,
                resume: { result in
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: value)
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
                        
                        let queued = pendingRequests
                        pendingRequests.removeAll()
                        
                        for item in queued {
                            Task {
                                do {
                                    let result: T = try await send(item.request)
                                    item.resumeAny(with: .success(result))
                                } catch {
                                    item.resumeAny(with: .failure(error))
                                }
                            }
                        }
                    } catch {
                        isRefreshingToken = false
                        let queued = pendingRequests
                        pendingRequests.removeAll()
                        for item in queued {
                            item.resumeAny(with: .failure(error))
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
    
    // MARK: - loadMockData（根 bundle）
    private func loadMockData(from fileName: String) -> Data? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}
