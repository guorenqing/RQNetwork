//
//  Data+Multipart.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// Data 扩展，支持 multipart/form-data 上传
public extension Data {
    mutating func appendMultipart(data: Data, name: String, fileName: String, mimeType: String, boundary: String) {
        self.append("--\(boundary)\r\n".data(using: .utf8)!)
        self.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        self.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        self.append(data)
        self.append("\r\n".data(using: .utf8)!)
    }
}

