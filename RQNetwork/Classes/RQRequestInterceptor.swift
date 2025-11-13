//
//  RQRequestInterceptor.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 请求拦截器协议
/// 可用于请求前日志、签名、修改参数等
public protocol RQRequestInterceptor {
    /// 请求发送前适配 URLRequest
    func adapt(_ request: URLRequest) async throws -> URLRequest
    
    /// 请求失败时是否重试
    func retry(_ request: URLRequest, dueTo error: Error) async -> Bool
}

