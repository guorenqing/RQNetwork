//
//  RQNetworkRequest.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 网络请求协议
/// 每个请求只需要定义 domainKey、path、method、可选 headers/query/body
public protocol RQNetworkRequest: Sendable {
    /// 域名标识，通过 DomainManager 获取 baseURL
    var domainKey: String { get }
    
    /// 请求路径
    var path: String { get }
    
    /// HTTP 方法
    var method: RQHTTPMethod { get }
    
    /// 请求头
    var headers: [String: String]? { get }
    
    /// query 参数
    var queryParameters: [String: String]? { get }
    
    /// body
    var body: Data? { get }
    
    /// 是否使用 Mock
    var useMock: Bool { get }
    
    /// 文件 Mock（优先级低）
    var mockFileName: String? { get }
        
    /// 直接返回 Mock 响应（优先级高）
    var mockResponse: Data? { get }
    
    /// 请求是否需要 token 授权
    var requiresAuth: Bool { get }
    
    /// 请求超时时间（秒），nil 使用网络库默认
    var timeoutInterval: TimeInterval? { get }
    
    /// 重试配置
    var retryConfiguration: RQRetryConfiguration? { get }
}

/// 默认实现：提供通用的默认配置
public extension RQNetworkRequest {
    
    /// 默认请求方法为 GET
    var method: RQHTTPMethod { .GET }
    
    /// 默认不需要自定义 headers
    var headers: [String: String]? { nil }
    
    /// 默认不需要自定义 query 参数
    var queryParameters: [String: String]? { nil }
    
    /// 默认无请求体
    var body: Data? { nil }
    
    /// 默认不使用 mock
    var useMock: Bool { false }
    
    /// 默认无文件 Mock
    var mockFileName: String? { nil }
        
    /// 默认无 Mock 响应
    var mockResponse: Data? { nil }
    
    /// 默认所有请求都需要权限（token）
    var requiresAuth: Bool { true }
    
    /// 请求超时时间（秒），nil 使用网络库默认
    var timeoutInterval: TimeInterval? { nil }
    
    /// 默认不重试（走NetworkManager重试策略）
    var retryConfiguration: RQRetryConfiguration? { nil }
}



