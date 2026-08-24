import Foundation

enum APIError: LocalizedError, Equatable {
    case notConfigured
    case invalidResponse
    case http(status: Int, message: String?)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "尚未配置服务器地址"
        case .invalidResponse: return "服务器响应格式不正确"
        case .http(let status, let message): return message ?? "请求失败（HTTP \(status)）"
        case .network(let detail): return "网络错误：\(detail)"
        }
    }
}

struct ErrorEnvelope: Decodable { let error: String? }

/// 忽略响应体的空类型：任何合法 JSON 都能解码成功。
struct EmptyResponse: Decodable {}

/// 类型化 fetch 封装 —— 语义对齐 web/src/lib/api.ts。
/// - 鉴权：Authorization: Bearer <token>（token 存 Keychain）
/// - 超时：请求 30s
final class APIClient: NSObject, URLSessionDelegate {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private static let tokenKey = "zhizhou.token"
    private static let allowInvalidCertKey = "zhizhou.allowInvalidCert"

    private override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        super.init()
    }

    // MARK: - 鉴权

    var token: String? {
        get { Keychain.load(Self.tokenKey) }
        set {
            if let newValue, !newValue.isEmpty {
                _ = Keychain.save(newValue, forKey: Self.tokenKey)
            } else {
                Keychain.delete(Self.tokenKey)
            }
        }
    }

    var isAuthenticated: Bool {
        guard let token, !token.isEmpty else { return false }
        return true
    }

    // MARK: - TLS（自托管开发场景）

    /// 是否信任无效证书（自签名/过期/域名不匹配）。默认开启便于连接自托管服务器；生产环境请关闭。
    var allowsInvalidCertificates: Bool {
        get { UserDefaults.standard.object(forKey: Self.allowInvalidCertKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.allowInvalidCertKey) }
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard allowsInvalidCertificates,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    // MARK: - 资源 URL

    func coverURL(novelId: String, updatedAt: Int64) -> URL? {
        guard let base = ServerConfig.shared.baseURL else { return nil }
        let path = base.appending(path: "api/cover/\(novelId)")
        var comps = URLComponents()
        comps.queryItems = [
            URLQueryItem(name: "v", value: String(updatedAt)),
            URLQueryItem(name: "cover", value: "2"),
        ]
        guard let query = comps.url?.query() else { return path }
        return URL(string: path.absoluteString + "?" + query)
    }

    func avatarURL(userId: String) -> URL? {
        guard let base = ServerConfig.shared.baseURL else { return nil }
        return base.appending(path: "api/avatar/\(userId)")
    }

    // MARK: - 请求

    private func makeURL(_ path: String) throws -> URL {
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            guard let url = URL(string: path) else { throw APIError.invalidResponse }
            return url
        }
        guard let base = ServerConfig.shared.baseURL else { throw APIError.notConfigured }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return base.appendingPathComponent(trimmed)
    }

    func request<T: Decodable>(_ method: String, _ path: String, body: Data? = nil, auth: Bool = false) async throws -> T {
        let url = try makeURL(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if auth, let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // 与 Web 端一致：不做浏览器 HTTP 缓存，始终拿最新数据
        req.setValue("no-store", forHTTPHeaderField: "Cache-Control")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let error as URLError {
            throw APIError.network(friendlyDescription(for: error))
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data))?.error
            throw APIError.http(status: http.statusCode, message: message)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    func get<T: Decodable>(_ path: String, auth: Bool = false) async throws -> T {
        try await request("GET", path, auth: auth)
    }

    func post<T: Decodable>(_ path: String, body: Data? = nil, auth: Bool = false) async throws -> T {
        try await request("POST", path, body: body, auth: auth)
    }

    func delete<T: Decodable>(_ path: String, auth: Bool = false) async throws -> T {
        try await request("DELETE", path, auth: auth)
    }

    /// 只关心状态码的请求（登录/登出/加书架等）
    func requestVoid(_ method: String, _ path: String, body: Data? = nil, auth: Bool = false) async throws {
        let _: EmptyResponse = try await request(method, path, body: body, auth: auth)
    }

    func jsonBody(_ value: some Encodable) throws -> Data {
        try JSONEncoder().encode(value)
    }

    /// TLS/证书类错误的友好提示，引导用户开启开发用证书放行开关
    private func friendlyDescription(for error: URLError) -> String {
        switch error.code {
        case .serverCertificateUntrusted,
             .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid,
             .secureConnectionFailed:
            return "TLS/证书错误：服务器证书不受信任。可在「服务器设置」中开启“信任无效证书（开发用）”后重试。"
        default:
            return error.localizedDescription
        }
    }
}
