//
//  RQRetryManager.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 重试管理器
final class RQRetryManager {
    
    /// 执行带重试的请求
    func executeWithRetry<T: Decodable>(
        request: RQNetworkRequest,
        urlRequest: URLRequest,
        urlSession: URLSession,
        responseInterceptors: [RQResponseInterceptor],
        tokenExpiredHandler: ((HTTPURLResponse, Data?) -> Bool)?,
        requiresAuth: Bool,
        defaultRetryConfig: RQRetryConfiguration?,
        networkManager: RQNetworkManager? = nil
    ) async throws -> T {
        
        // 优先级：request配置 > manager默认配置 > 不重试
        let configuration: RQRetryConfiguration?
        if let requestConfig = request.retryConfiguration {
            configuration = requestConfig
        } else {
            configuration = defaultRetryConfig
        }
        
        // 如果没有重试配置，直接执行单次请求
        guard let config = configuration else {
            return try await executeSingleRequest(
                urlRequest: urlRequest,
                urlSession: urlSession,
                responseInterceptors: responseInterceptors,
                tokenExpiredHandler: tokenExpiredHandler,
                requiresAuth: requiresAuth
            )
        }
        
        var lastError: Error?
        var retryCount = 0
        
        while retryCount <= config.maxRetryCount {
            do {
                return try await executeSingleRequest(
                    urlRequest: urlRequest,
                    urlSession: urlSession,
                    responseInterceptors: responseInterceptors,
                    tokenExpiredHandler: tokenExpiredHandler,
                    requiresAuth: requiresAuth
                )
                
            } catch RQNetworkError.tokenExpired {
                // 🔧 Token 过期，使用统一的认证处理方法
                guard let networkManager = networkManager, requiresAuth else {
                    throw RQNetworkError.tokenExpired
                }
                
                // 等待 Token 刷新完成
                _ = try await networkManager.handleAuthFailure()
                
                // 🔧 刷新成功后重新执行当前请求（不增加重试计数）
                // 因为 Token 刷新不是普通的网络错误重试
                continue
                
            } catch {
                lastError = error
                
                
                // 检查是否应该重试
                let shouldRetry = shouldRetry(
                    error: error,
                    request: urlRequest,
                    response: nil,
                    configuration: config,
                    retryCount: retryCount
                )
                
                guard shouldRetry else {
                    throw error
                }
                
                // 计算延迟并等待
                let delay = config.delayStrategy.delay(for: retryCount)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                retryCount += 1
                
                if logEnabled {
                    print("🔄 [RQNetwork] Retry \(retryCount)/\(config.maxRetryCount) after \(delay)s, error: \(error)")
                }
            }
        }
        
        throw lastError ?? RQNetworkError.requestFailed(NSError(domain: "Unknown", code: -1))
    }
    
    private func executeSingleRequest<T: Decodable>(
        urlRequest: URLRequest,
        urlSession: URLSession,
        responseInterceptors: [RQResponseInterceptor],
        tokenExpiredHandler: ((HTTPURLResponse, Data?) -> Bool)?,
        requiresAuth: Bool
    ) async throws -> T {
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RQNetworkError.invalidResponse
        }
        
        // token过期处理
        if let handler = tokenExpiredHandler, handler(httpResponse, data), requiresAuth {
            throw RQNetworkError.tokenExpired
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
    }
    
    private func shouldRetry(
        error: Error,
        request: URLRequest,
        response: HTTPURLResponse?,
        configuration: RQRetryConfiguration,
        retryCount: Int
    ) -> Bool {
        guard retryCount < configuration.maxRetryCount else {
            return false
        }
        // 🔧 token过期错误不应该重试
        if case RQNetworkError.tokenExpired = error {
            return false
        }
        
        return configuration.retryCondition.shouldRetry(
            error: error,
            request: request,
            response: response
        )
    }
    
    private var logEnabled: Bool {
        return true
    }
}
