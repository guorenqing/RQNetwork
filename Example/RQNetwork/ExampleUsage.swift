//
//  ExampleUsage.swift
//  RQNetwork_Example
//
//  Created by edy on 2025/11/13.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import Foundation
import RQNetwork



@main
struct RQExampleApp {
    static func main() async {
        
        // 设置当前环境
        RQDomainManager.setupDomains()
        RQDomainManager.shared.setEnvironment(.develop("d1"))
        
        
        // 设置动态 headers & query
        RQNetworkManager.shared.commonHeadersProvider = {
            ["Authorization": "Bearer token_123", "App-Version": "1.0.0"]
        }
        RQNetworkManager.shared.commonQueryParametersProvider = {
            ["timestamp": "\(Date().timeIntervalSince1970)"]
        }
        
        // 添加请求/响应拦截器
        RQNetworkManager.shared.interceptors = [RQLogInterceptor(), RQMD5Interceptor()]
        RQNetworkManager.shared.responseInterceptors = [RQResponseLogInterceptor()]
        
        // token 刷新回调
        RQNetworkManager.shared.refreshTokenHandler = {
            print("🔑 Refreshing token...")
        }
        
        // token 过期判断回调
        RQNetworkManager.shared.tokenExpiredHandler = { response, data in
            // JSON 中 code = 1001 表示 token 过期
            guard let data = data else { return false }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json?["code"] as? Int {
                return code == 1001
            }
            return false
        }
        
        // 发送请求
        do {
            let user: User = try await RQNetworkManager.shared.send(UserRequest(userId: "12345"))
            print("✅ User info:", user)
        } catch {
            print("❌ Request failed:", error)
        }
    }
}

