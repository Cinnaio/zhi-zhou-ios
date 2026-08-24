import Foundation
import Combine

/// 服务器地址配置：自托管场景每个实例地址不同，用户首次启动必须配置。
final class ServerConfig: ObservableObject {
    static let shared = ServerConfig()

    @Published var rawURL: String {
        didSet { UserDefaults.standard.set(rawURL, forKey: Self.storageKey) }
    }

    private static let storageKey = "zhizhou.serverURL"

    private init() {
        rawURL = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
    }

    /// 规范化后的 base URL（去掉尾部斜杠、自动补 https:// 前缀）
    var baseURL: URL? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var value = trimmed
        while value.hasSuffix("/") { value.removeLast() }
        if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
            value = "https://" + value
        }
        return URL(string: value)
    }

    var hasServer: Bool { baseURL != nil }
}
