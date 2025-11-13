//
//  RQMD5Interceptor.swift
//  RQNetwork_Example
//
//  Created by guorenqing on 2025/11/13.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import RQNetwork
import CommonCrypto

// 请求拦截器示例：MD5 签名
struct RQMD5Interceptor: RQRequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        guard let body = req.httpBody else { return req }
        var headers = req.allHTTPHeaderFields ?? [:]
        headers["X-Signature"] = body.md5
        req.allHTTPHeaderFields = headers
        return req
    }
    func retry(_ request: URLRequest, dueTo error: Error) async -> Bool { false }
}

// Data MD5 扩展
extension Data {
    var md5: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        self.withUnsafeBytes { _ = CC_MD5($0.baseAddress, CC_LONG(self.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

