# 📡 RQNetwork
[English](./README_EN.md) | [简体中文](./README_CN.md)
> A modern, lightweight, and flexible Swift networking library — designed for modular microservice apps with multi-environment, token refresh queue, interceptors, mock support, and async/await.

---

## ✨ Features

* ✅ **Multi-domain & Multi-environment**

  * Built-in `RQDomainManager` supports multiple base URLs per environment (e.g. dev/test/prod/mock)
  * Each request specifies a `domainKey`, resolved dynamically at runtime

* 🔐 **Token Refresh Queue**

  * When short token expires, all pending requests requiring authentication are queued
  * Automatically re-sent once token refresh succeeds

* ⚙️ **Dynamic Common Parameters**

  * Common headers & query parameters provided by closures
  * Perfect for dynamic fields like timestamps or auth tokens

* 🧩 **Request & Response Interceptors**

  * Request interceptors: modify or sign outgoing requests (e.g. MD5 signature)
  * Response interceptors: log or transform responses before decoding

* 🧱 **Environment Switching**

  * Switch environment at runtime: `.develop("d1")`, `.test("t2")`, `.production`, `.mock`
  * Ideal for internal staging or A/B testing setups

* 🧰 **Mock Support**

  * Local mock data for testing without hitting real APIs

* 🧾 **Upload / Download Ready**

  * Built-in multipart-form data utilities for file uploads

* 🧑‍💻 **Modern Swift Concurrency**

  * Uses async/await with `URLSession.data(for:)`

---

## 🧩 Project Structure

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

## 🚀 Quick Start

### 1️⃣ Register Domains

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

### 2️⃣ Configure Global Settings

```swift
RQNetworkManager.shared.commonHeadersProvider = {
    ["Authorization": "Bearer token_123", "App-Version": "1.0.0"]
}

RQNetworkManager.shared.commonQueryParametersProvider = {
    ["timestamp": "\(Date().timeIntervalSince1970)"]
}

RQNetworkManager.shared.tokenExpiredHandler = { response, data in
    guard let data = data else { return false }
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let code = json["code"] as? Int {
        return code == 1001 // Token expired
    }
    return false
}

RQNetworkManager.shared.refreshTokenHandler = {
    print("🔑 Refreshing token...")
}
```

---

### 3️⃣ Define Your Request

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

### 4️⃣ Send Request

```swift
struct User: Decodable {
    let id: Int
    let name: String
}

do {
    let user: User = try await RQNetworkManager.shared.request(UserRequest(), responseType: User.self)
    print("✅ User:", user)
} catch {
    print("❌ Request failed:", error)
}
```

---

## 🧰 Example Interceptors

### Request Logging Interceptor

```swift
struct RQLogInterceptor: RQRequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        print("📤 Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        return request
    }
    func retry(_ request: URLRequest, dueTo error: Error) async -> Bool { false }
}
```

### MD5 Signature Interceptor

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

### Response Logging Interceptor

```swift
struct RQResponseLogInterceptor: RQResponseInterceptor {
    func intercept<T>(data: Data?, response: URLResponse?, error: Error?) async {
        if let err = error {
            print("❌ Response Error: \(err)")
        } else if let resp = response as? HTTPURLResponse, let data = data {
            print("✅ Response \(resp.statusCode): \(String(data: data, encoding: .utf8) ?? "<non-string>")")
        }
    }
}
```

---

## ⚙️ Environment Enum

```swift
public enum RQEnvironment: Equatable {
    case mock
    case develop(String)
    case test(String)
    case preProduction
    case production
}
```

> Each environment can carry a name like `"d1"`, `"t2"` for fine-grained control over multiple internal instances.

---

## 🧱 Domain Key Enum

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

---

## 📦 Installation

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

## 🧠 Design Philosophy

* **Composable** — Small, independent components
* **Customizable** — Extend via interceptors, hooks, and providers
* **Concurrent-safe** — Uses structured concurrency (async/await)
* **Business-agnostic** — No hardcoded logic; fully reusable across apps

---

## 🧑‍💻 Author

**RenQing (RQ)**
iOS Developer • Swift Architect • Open Source Enthusiast

📧 Email: [youremail@example.com](mailto:youremail@example.com)
🌐 GitHub: [https://github.com/yourusername](https://github.com/yourusername)

---

## 🪪 License

MIT License © 2025 RenQing
See [LICENSE](LICENSE) for details.
