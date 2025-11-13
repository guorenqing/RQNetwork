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
    var domainKey = RQDomainKey.userService.key
    var path = "/users/1"
    var method = RQHTTPMethod.GET
    var headers: [String : String]? = nil
    var queryParameters: [String : String]? = nil
    var body: Data? = nil
    var useMock: Bool = true
    var mockFileName: String? = "user"
    var requiresAuth: Bool = true
}
