import SwiftUI

extension Color {
    /// 从 "#RRGGBB" 十六进制字符串创建颜色
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

/// 知舟设计系统：暖调奶油 · 治愈手账风。
/// 暖纸面背景 + 奶茶棕强调色；衬线（宋体）标题营造书卷感，正文用系统无衬线。
enum AppTheme {
    // MARK: 主色（奶茶棕 · 品牌强调）
    static let primary = Color(hex: "8B6045")
    static let primaryDeep = Color(hex: "6E4A34")
    static let primaryLight = Color(hex: "F5E7D3")

    // MARK: 纸面 / 背景
    static let background = Color(hex: "FBF6EE")        // 奶油纸面
    static let surfaceWarm = Color(hex: "F7F0E2")       // 暖亚麻
    static let surface = Color(hex: "FFFDF9")           // 亮纸面
    static let border = Color(hex: "EADFCF")            // 暖边线

    // MARK: 文字
    static let textPrimary = Color(hex: "3A2E24")       // 深咖啡
    static let textSecondary = Color(hex: "6B5D4F")
    static let textMuted = Color(hex: "8A7A68")

    // MARK: 附属暖色
    static let terracotta = Color(hex: "C97B5A")        // 陶土
    static let peach = Color(hex: "F2C9A0")             // 蜜桃
    static let butter = Color(hex: "E8C79A")            // 黄油
    static let sage = Color(hex: "A9B89B")              // 鼠尾草
    static let rose = Color(hex: "D8A4A0")              // 干玫瑰

    static let success = Color(hex: "7A8B6F")
    static let warning = Color(hex: "C99A4B")
    static let danger = Color(hex: "B86A5A")
    static let seal = Color(hex: "B8453A")              // 收藏印章

    // MARK: 玻璃背景渐变
    /// 主界面暖纸面（浅色玻璃卡片浮在其上）
    static let glassBackground = LinearGradient(
        colors: [Color(hex: "FFF9F0"), Color(hex: "FAF0E1"), Color(hex: "F5E7D6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 登录页暖光背景（奶油 → 蜜桃，温和治愈）
    static let auroraBackground = LinearGradient(
        colors: [Color(hex: "FBF4E9"), Color(hex: "F6E7D4"), Color(hex: "EED5BC"), Color(hex: "E4BFA2")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 主按钮渐变（奶茶棕）
    static let buttonGradient = LinearGradient(
        colors: [Color(hex: "A07150"), Color(hex: "8B6045"), Color(hex: "6E4A34")],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 品牌图标渐变（蜜桃 → 陶土）
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "F2C9A0"), Color(hex: "E0A177"), Color(hex: "C97B5A")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 字体

/// 衬线（宋体）字体：标题用，营造印刷书卷 / 手账感。
/// 必须用 PostScript 名（STSongti-SC-*）而非字族名「Songti SC」，
/// 否则 `Font.custom` 会静默回退成系统无衬线，看起来就是"没生效"。
func serifFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    switch weight {
    case .bold, .semibold, .heavy, .black:
        return Font.custom("STSongti-SC-Bold", size: size)
    default:
        return Font.custom("STSongti-SC-Regular", size: size)
    }
}

// MARK: - View 扩展

extension View {
    /// 页面级玻璃背景：暖纸面渐变铺满安全区
    func glassPageBackground() -> some View {
        self.background(AppTheme.glassBackground.ignoresSafeArea())
    }

    /// 列表在暖纸面上常用的半透明白色行底（frosted row）
    func frostedRowBackground() -> some View {
        self.listRowBackground(Color.white.opacity(0.55))
    }
}
