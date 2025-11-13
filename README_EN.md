# 📡 RQNetwork

> 一个现代化、轻量级、可扩展的 Swift 网络库。
> 为多域名、多环境、微服务架构设计，支持 token 队列化刷新、请求/响应拦截器、Mock 数据、文件上传下载、动态公共参数、以及 async/await 并发。

---

## ✨ 功能特性

* ✅ **多域名 & 多环境**

  * 内置 `RQDomainManager`，可为每个环境（开发/测试/预发布/生产）配置不同 baseURL
  * 每个请求通过 `domainKey` 自动选择对应域名

* 🔐 **短 Token 刷新队列化**

  * 当 token 过期时，将需要授权的请求加入队列
  * token 刷新成功后自动重试所有挂起请求

* ⚙️ **动态公共参数**

  * 支持通过回调提供 headers 和 query 参数
  * 适合动态参数（如时间戳、auth token）

* 🧩 **请求 / 响应拦截器**

  * 请求拦截器：用于添加签名、打印日志、修改参数
  * 响应拦截器：用于统一日志、错误处理或数据解析

* 🧱 **多环境切换**

  * 运行时可切换环境：`.develop("d1")`, `.test("t2")`, `.production`, `.mock`
  * 方便调试不同后端环境或 A/B 测试

* 🧰 **Mock 支持**

  * 可使用本地 JSON 文件进行接口模拟测试

* 🧾 **文件上传 / 下载**

  * 内置 multipart-form 工具，支持文件上传

* 🧑‍💻 **现代 Swift 并发**

  * 使用 async/await 与 `URLSession.data(for:)` 实现异步调用

---

## 🧩 项目结构

```
RQNetwork/
├── Sources/RQNetwork/
│   ├── RQHTTPMethod.swift
│   ├── RQNetworkError.swift
│   ├── RQEnvironment.swift
│   ├── RQDomainManager.swift
│   ├── RQNetworkRequest.swift
│   ├── RQRequestInterceptor.swift
│   ├── RQResponseInterceptor.swift
│   ├── RQNetworkManager.swift
│   ├── Extensions/
│   │   └── Data+Multipart.swift
│   └── Domain/
│       └── RQDomainKey.swift
└── Example/RQNetworkExampleApp/
    └── ExampleUsage.swift
```

---

## 🚀 快速开始

### 1️⃣ 注册域名

```swift
RQDomainManager.shared.registerDomain(
    key: RQDomainKey.userService.key,
    urls: [
        .develop("d1"): "https://dev1.example.com",
        .test("t1"): "https://test1.example.com",
        .production: "https://api.example.com"
    ]
)
RQDomainManager.shared.setEnvironment(.develop("d1"))
```

---

### 2️⃣ 配置全局参数与回调

```swift
RQNetworkManager.shared.commonHeadersProvider = {
    ["Authorization": "Bearer token_123", "App-Version": "1.0.0"]
}

RQNetworkManager.shared.commonQueryParametersProvider = {
    ["timestamp": "\(Date().timeIntervalSince1970)"]
}

/// token 过期判断逻辑
RQNetworkManager.shared.tokenExpiredHandler = { response, data in
    guard let data = data else { return false }
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let code = json["code"] as? Int {
        return code == 1001 // 业务层定义：code = 1001 表示 token 失效
    }
    return false
}

/// token 刷新逻辑
RQNetworkManager.shared.refreshTokenHandler = {
    print("🔑 正在刷新 token ...")
}
```

---

### 3️⃣ 定义请求模型

```swift
struct UserRequest: RQNetworkRequest {
    var domainKey = RQDomainKey.userService.key
    var path = "/users/1"
    var method = .GET
    var headers: [String : String]? = nil
    var queryParameters: [String : String]? = nil
    var body: Data? = nil
    var useMock: Bool = false
    var mockFileName: String? = nil
    var requiresAuth: Bool = true
}
```

---

### 4️⃣ 发送请求

```swift
struct User: Decodable {
    let id: Int
    let name: String
}

do {
    let user: User = try await RQNetworkManager.shared.request(UserRequest(), responseType: User.self)
    print("✅ 用户信息:", user)
} catch {
    print("❌ 请求失败:", error)
}
```

---

## 🧰 示例拦截器

### 请求日志拦截器

```swift
struct RQLogInterceptor: RQRequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        print("📤 请求：\(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        return request
    }
    func retry(_ request: URLRequest, dueTo error: Error) async -> Bool { false }
}
```

### MD5 签名拦截器

```swift
struct RQMD5Interceptor: RQRequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        guard let body = req.httpBody else { return req }
        var headers = req.allHTTPHeaderFields ?? [:]
        headers["X-Signature"] = body.md5
        req.allHTTPHeaderFields = headers
        return req
    }
    func retry(_ request: URLRequest, dueTo error: Error) async -> Bool { false }
}
```

### 响应日志拦截器

```swift
struct RQResponseLogInterceptor: RQResponseInterceptor {
    func intercept<T>(data: Data?, response: URLResponse?, error: Error?) async {
        if let err = error {
            print("❌ 响应错误：\(err)")
        } else if let resp = response as? HTTPURLResponse, let data = data {
            print("✅ 响应 \(resp.statusCode)：\(String(data: data, encoding: .utf8) ?? "<非字符串>")")
        }
    }
}
```

---

## ⚙️ 环境枚举定义

```swift
public enum RQEnvironment: Equatable {
    case mock
    case develop(String)
    case test(String)
    case preProduction
    case production
}
```

> 示例：
> `.develop("d1")` 表示开发环境 d1
> `.test("t2")` 表示测试环境 t2

---

## 🧱 域名 Key 枚举定义

```swift
public enum RQDomainKey: String, CaseIterable {
    case userService
    case orderService
    case paymentService
    case analyticsService
    case messageService
    case other
    
    public var key: String { rawValue }
}
```

> 这样可以避免在业务代码中硬编码字符串 key，书写更安全。

---

## 📦 安装方式

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/RQNetwork.git", from: "0.1.0")
]
```

### CocoaPods

```ruby
pod 'RQNetwork', '~> 0.1.0'
```

---

## 🧠 设计理念

| 原则      | 说明                         |
| ------- | -------------------------- |
| 🧩 模块化  | 网络层与业务完全解耦，可单独作为库复用        |
| ⚙️ 可扩展  | 通过拦截器、回调、配置自由组合            |
| 🔒 并发安全 | 使用 Swift 并发模型（async/await） |
| 💡 业务无关 | 不包含任何业务逻辑，可嵌入任何 App 项目     |

---

## 👨‍💻 作者

**郭仁庆（guorenqing）**
iOS 开发者 • Swift 架构师 • 开源爱好者

📧 Email: [guorenqing@sina.com](mailto:guorenqing@sina.com)
🌐 GitHub: [https://github.com/guorenqing](https://github.com/guorenqing)

---

## 🪪 开源协议

MIT License © 2025 guorenqing
详见 [LICENSE](LICENSE)
