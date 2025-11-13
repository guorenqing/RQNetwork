//
//  RQLogInterceptor.swift
//  RQNetwork_Example
//
//  Created by guorenqing on 2025/11/13.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import RQNetwork

// 请求拦截器示例：日志
struct RQLogInterceptor: RQRequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        print("📤 Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        return request
    }
    func retry(_ request: URLRequest, dueTo error: Error) async -> Bool { false }
}
