//
//  RQRetryConfiguration.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 重试配置
public struct RQRetryConfiguration {
    /// 最大重试次数
    public let maxRetryCount: Int
    
    /// 重试延迟策略
    public let delayStrategy: RQRetryDelayStrategy
    
    /// 重试条件判断
    public let retryCondition: RQRetryCondition
    
    public init(
        maxRetryCount: Int = 3,
        delayStrategy: RQRetryDelayStrategy = .exponentialBackoff(base: 2.0),
        retryCondition: RQRetryCondition = .default
    ) {
        self.maxRetryCount = maxRetryCount
        self.delayStrategy = delayStrategy
        self.retryCondition = retryCondition
    }
    
    /// 默认配置
    public static let `default` = RQRetryConfiguration()
}

/// 重试延迟策略
public enum RQRetryDelayStrategy {
    /// 固定延迟
    case fixed(TimeInterval)
    
    /// 指数退避
    case exponentialBackoff(base: Double, maxDelay: TimeInterval = 60.0)
    
    /// 自定义延迟计算
    case custom((Int) -> TimeInterval)
    
    func delay(for retryCount: Int) -> TimeInterval {
        switch self {
        case .fixed(let interval):
            return interval
        case .exponentialBackoff(let base, let maxDelay):
            let delay = pow(base, Double(retryCount))
            return min(delay, maxDelay)
        case .custom(let calculator):
            return calculator(retryCount)
        }
    }
}

/// 重试条件
public struct RQRetryCondition {
    private let condition: (Error, URLRequest, HTTPURLResponse?) -> Bool
    
    public init(condition: @escaping (Error, URLRequest, HTTPURLResponse?) -> Bool) {
        self.condition = condition
    }
    
    public func shouldRetry(error: Error, request: URLRequest, response: HTTPURLResponse?) -> Bool {
        return condition(error, request, response)
    }
    
    /// 默认重试条件
    public static let `default` = RQRetryCondition { error, request, response in
        
        // 🔧 token过期错误不应该重试
        if case RQNetworkError.tokenExpired = error {
            return false
        }
        
        // 超时错误
        if case RQNetworkError.timeout = error {
            return true
        }
        
        // 5xx 服务器错误
        if case RQNetworkError.statusCode(let code) = error, (500...599).contains(code) {
            return true
        }
        
        // URL 错误
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .secureConnectionFailed:
                return true
            default:
                break
            }
        }
        
        return false
    }
    
    /// 不重试
    public static let never = RQRetryCondition { _, _, _ in false }
    
    /// 总是重试（谨慎使用）
    public static let always = RQRetryCondition { _, _, _ in true }
    
    /// 自定义状态码重试
    public static func statusCodes(_ codes: Set<Int>) -> RQRetryCondition {
        return RQRetryCondition { error, _, _ in
            if case RQNetworkError.statusCode(let code) = error {
                return codes.contains(code)
            }
            return false
        }
    }
}
