//
//  RQDomainManager.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 域名管理器
/// 统一管理 domainKey 对应的多环境 baseURL
public final class RQDomainManager {
    
    public static let shared = RQDomainManager()
    private init() {}
    
    /// 当前全局环境
    private var currentEnvironment: RQEnvironment = .production
    
    /// domainKey -> environment -> baseURL
    private var domainMapping: [String: [RQEnvironment: String]] = [:]
    
    /// 设置当前全局环境
    public func setEnvironment(_ env: RQEnvironment) {
        currentEnvironment = env
    }
    
    /// 注册域名
    public func registerDomain(key: String, urls: [RQEnvironment: String]) {
        domainMapping[key] = urls
    }
    
    /// 根据 domainKey 获取当前环境下的 baseURL
    public func getDomain(_ key: String) -> String? {
        return domainMapping[key]?[currentEnvironment]
    }
    
    /// 获取当前环境
    public func currentEnv() -> RQEnvironment {
        return currentEnvironment
    }
}

