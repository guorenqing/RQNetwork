//
//  RQNetworkError.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 网络请求错误类型
public enum RQNetworkError: Error {
    case invalidURL                  // URL 无效
    case requestFailed(Error)        // 请求失败
    case invalidResponse             // 响应无效
    case statusCode(Int)             // HTTP 状态码错误
    case decodingFailed(Error)       // JSON 解析失败
    case tokenExpired                // token 失效
    case mockDataNotFound            // mock 数据没找到
    case timeout                     // 🔧 请求超时
}

