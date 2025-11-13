//
//  RQNetworkRequest.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 网络请求协议
/// 每个请求只需要定义 domainKey、path、method、可选 headers/query/body
public protocol RQNetworkRequest {
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
    
    /// Mock 文件名
    var mockFileName: String? { get }
    
    /// 请求是否需要 token 授权
    var requiresAuth: Bool { get }
}

