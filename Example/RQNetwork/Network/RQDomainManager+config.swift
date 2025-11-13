//
//  RQDomainManager+domainConfig.swift
//  RQNetwork_Example
//
//  Created by guorenqing on 2025/11/13.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import RQNetwork

public extension RQDomainManager {
    /// 批量注册所有服务域名
    static func setupDomains() {
        shared.registerDomain(
            key: RQDomainKey.userService.key,
            urls: [
                .develop("d1"): "https://dev1.example.com",
                .develop("d2"): "https://dev2.example.com",
                .test("t1"): "https://test1.example.com",
                .test("t2"): "https://test2.example.com",
                .preProduction: "https://pre.example.com",
                .production: "https://prod.example.com",
                .mock: "mock://local"
            ]
        )
        shared.registerDomain(
            key: RQDomainKey.orderService.key,
            urls: [
                .develop("d1"): "https://dev1.example.com",
                .develop("d2"): "https://dev2.example.com",
                .test("t1"): "https://test1.example.com",
                .test("t2"): "https://test2.example.com",
                .preProduction: "https://pre.example.com",
                .production: "https://prod.example.com",
                .mock: "mock://local"
            ]
        )
    }
}
