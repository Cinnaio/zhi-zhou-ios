import SwiftUI

extension Color {
    /// 从 "#RRGGBB" 十六进制字符串创建颜色（自托管 DESIGN.md 的奶茶奶油色板）
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        for ch in s {
            value <<= 4
            if let digit = ch.hexDigitValue { value |= UInt64(digit) }
        }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

/// 知舟设计系统 token（DESIGN.md）：奶茶·奶油暖色调
enum AppTheme {
    static let primary = Color(hex: "8B6045")        // Milk-Tea Brown（唯一强调色）
    static let primaryDeep = Color(hex: "74503A")
    static let primaryLight = Color(hex: "F0E6D6")
    static let surface = Color(hex: "FFFFFF")        // Clean Paper
    static let surfaceWarm = Color(hex: "F6F4F1")    // Warm Linen（页面地面）
    static let textPrimary = Color(hex: "211E1A")    // Espresso Ink
    static let textSecondary = Color(hex: "5B554E")
    static let textMuted = Color(hex: "736D65")
    static let border = Color(hex: "ECE8E2")
    static let success = Color(hex: "4F7A52")
    static let warning = Color(hex: "B07C2F")
    static let danger = Color(hex: "BE123C")
    static let seal = Color(hex: "b8453a")           // 收藏印章色
}
