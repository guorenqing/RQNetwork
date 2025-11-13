//
//  RQDomainKey.swift
//  RQNetwork_Example
//
//  Created by guorenqing on 2025/11/13.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import Foundation

/// 域名 Key 枚举
/// 用于从 RQDomainManager 获取对应域名，避免字符串硬编码
public enum RQDomainKey: String, CaseIterable {
    
    /// 用户服务域名
    case userService
    
    /// 订单服务域名
    case orderService
    
    /// 支付服务域名
    case paymentService
    
    /// 消息中心
    case messageService
    
    /// 统计分析
    case analyticsService
    
    /// 其他自定义模块...
    case other
    
    /// 快捷访问 rawValue 字符串
    public var key: String { rawValue }
}

