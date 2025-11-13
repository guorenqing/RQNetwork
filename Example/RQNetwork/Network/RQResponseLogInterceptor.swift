//
//  RQResponseLogInterceptor.swift
//  RQNetwork_Example
//
//  Created by guorenqing on 2025/11/13.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import RQNetwork

// 响应拦截器示例：响应日志
struct RQResponseLogInterceptor: RQResponseInterceptor {
    func intercept(data: Data?, response: URLResponse?, error: Error?) async {
        if let err = error {
            print("❌ Response Error: \(err)")
        } else if let resp = response as? HTTPURLResponse, let data = data {
            print("✅ Response \(resp.statusCode): \(String(data: data, encoding: .utf8) ?? "<non-string>")")
        }
    }
}
