//
//  RQFileDownload.swift
//  RQNetwork
//
//  Created by guorenqing on 2025/11/13.
//

import Foundation

/// 下载进度回调
public typealias RQDownloadProgressHandler = (Double) -> Void

/// 下载目的地
public enum RQDownloadDestination: Sendable {
    /// 下载到临时目录
    case temporary
    /// 下载到文档目录，指定文件名
    case document(String)
    /// 下载到缓存目录，指定文件名
    case caches(String)
    /// 自定义文件 URL
    case custom(URL)
    
    func makeURL() -> URL {
        switch self {
        case .temporary:
            return FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        case .document(let fileName):
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return documentsURL.appendingPathComponent(fileName)
        case .caches(let fileName):
            let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            return cachesURL.appendingPathComponent(fileName)
        case .custom(let url):
            return url
        }
    }
}

/// 下载响应
public struct RQDownloadResponse {
    public let localURL: URL
    public let totalBytesReceived: Int64
    public let totalBytesExpectedToReceive: Int64
    
    public init(localURL: URL, totalBytesReceived: Int64, totalBytesExpectedToReceive: Int64) {
        self.localURL = localURL
        self.totalBytesReceived = totalBytesReceived
        self.totalBytesExpectedToReceive = totalBytesExpectedToReceive
    }
}
