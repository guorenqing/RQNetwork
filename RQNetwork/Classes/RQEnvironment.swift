//
//  RQEnvironment.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 网络环境类型
/// develop/test 关联值为环境名称，例如 d1、d2、t1、t2
public enum RQEnvironment: Equatable, Hashable {
    case mock
    case develop(String)
    case test(String)
    case preProduction
    case production
}

