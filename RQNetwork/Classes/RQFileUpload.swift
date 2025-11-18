//
//  RQFileUpload.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 文件上传项
public struct RQUploadFile {
    public let data: Data
    public let name: String
    public let fileName: String
    public let mimeType: String
    
    public init(data: Data, name: String, fileName: String, mimeType: String) {
        self.data = data
        self.name = name
        self.fileName = fileName
        self.mimeType = mimeType
    }
    
    /// 快速创建图片上传
    public static func image(_ imageData: Data, name: String, fileName: String = "image.jpg") -> RQUploadFile {
        return RQUploadFile(data: imageData, name: name, fileName: fileName, mimeType: "image/jpeg")
    }
    
    /// 快速创建文件上传
    public static func file(_ fileData: Data, name: String, fileName: String, mimeType: String) -> RQUploadFile {
        return RQUploadFile(data: fileData, name: name, fileName: fileName, mimeType: mimeType)
    }
}

/// 文件上传请求协议
public protocol RQFileUploadRequest: RQNetworkRequest {
    /// 上传的文件列表
    var files: [RQUploadFile] { get }
    
    /// 其他表单字段
    var formFields: [String: String]? { get }
}

/// 上传进度回调
public typealias RQUploadProgressHandler = (Double) -> Void

/// 上传响应
public struct RQUploadResponse<T: Decodable> {
    public let response: T
    public let totalBytesSent: Int64
    public let totalBytesExpectedToSend: Int64
}

// MARK: - 默认实现
public extension RQFileUploadRequest {
    /// 默认需要权限验证
    var requiresAuth: Bool { true }
    
    /// 默认不使用 mock
    var useMock: Bool { false }
}
