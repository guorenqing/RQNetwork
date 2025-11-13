//
//  RQResponseInterceptor.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 响应拦截器协议
/// 可用于响应日志、统一错误处理
public protocol RQResponseInterceptor {
    func intercept(data: Data?, response: URLResponse?, error: Error?) async
}

