import Foundation
import Security

/// 极简 Keychain 封装：登录 token 存 Keychain，不落 UserDefaults。
enum Keychain {
    private static func baseQuery(forKey key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrAccount as String: key]
    }

    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(forKey: key).merging([kSecValueData as String: data]) { _, new in new }
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load(_ key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    }
}
