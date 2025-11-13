//
//  UserRequest.swift
//  RQNetwork_Example
//
//  Created by guorenqing on 2025/11/13.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import RQNetwork

// Mock User
struct User: Decodable {
    let id: Int
    let name: String
    let username: String
    let email: String
}

// 示例 Request
struct UserRequest: RQNetworkRequest {
    var userId: String
    var domainKey = RQDomainKey.userService.key
    var path: String { "/users/\(userId)" } // 动态路径
    var queryParameters: [String: String]? { ["userId": userId] }
    
    init(userId: String) {
        self.userId = userId
    }
}

