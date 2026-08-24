import Foundation
import SwiftUI

/// 阅读设置：本地立即生效 + 与服务器 LWW 合并同步。
/// 键值表与 api/src/services/reader-settings.ts 完全一致。
final class ReaderSettingsStore: ObservableObject {
    static let shared = ReaderSettingsStore()

    @Published var values: [String: String] = [:]
    @Published var updatedAt: [String: Int64] = [:]

    private var syncTask: Task<Void, Never>?
    private let knownKeys: Set<String> = [
        "fontSize", "fontFamily", "readerPageMode", "readerTheme", "readerLineHeight",
        "readerParagraphSpacing", "readerWakeLock", "readerPageWidth",
        "readerAutoScrollSpeed", "readerClickPaging", "contentMode",
    ]

    private init() {
        values = [
            "fontSize": "2",
            "fontFamily": "serif",
            "readerPageMode": "scroll",
            "readerTheme": "default",
            "readerLineHeight": "1.95",
            "readerParagraphSpacing": "1.4",
            "contentMode": "safe",
        ]
    }

    // MARK: - 读取（带默认值）

    var fontSizeIndex: Int {
        let levels = ["0", "1", "2", "3", "4", "5"]
        return levels.firstIndex(of: values["fontSize"] ?? "2") ?? 2
    }

    var bodyFontSize: CGFloat { [14, 16, 18, 20, 22, 24][fontSizeIndex] }
    var lineHeight: CGFloat { CGFloat(Double(values["readerLineHeight"] ?? "1.95") ?? 1.95) }
    var themeName: String { values["readerTheme"] ?? "default" }
    var useSerif: Bool { (values["fontFamily"] ?? "serif") == "serif" }
    var contentMode: String { values["contentMode"] ?? "safe" }

    /// 阅读器纸面背景（对应 Web 端 readerTheme：default=纸面 / eye=护眼 / paper=羊皮纸）
    var backgroundColor: Color {
        switch themeName {
        case "eye": return Color(hex: "C7EDCC")
        case "paper": return Color(hex: "F5E9D3")
        default: return Color(hex: "F6F4F1")
        }
    }

    var textColor: Color { Color(hex: "211E1A") }

    var bodyFont: Font {
        useSerif
            ? Font.custom("Songti SC", size: bodyFontSize)
            : .system(size: bodyFontSize)
    }

    var titleFont: Font {
        useSerif
            ? Font.custom("Songti SC", size: bodyFontSize + 4).bold()
            : .system(size: bodyFontSize + 4, weight: .bold)
    }

    /// 行距增量 = 字号 × (行高系数 - 1)
    var lineSpacing: CGFloat { bodyFontSize * (lineHeight - 1) }

    // MARK: - 写入 + 同步

    func set(_ key: String, _ value: String) {
        guard knownKeys.contains(key) else { return }
        values[key] = value
        updatedAt[key] = Int64(Date().timeIntervalSince1970 * 1000)
        scheduleSync()
    }

    /// 进入 App 时拉取服务端设置（LWW：服务端时间戳更新则采纳）
    func syncFromServer() async {
        guard APIClient.shared.isAuthenticated else { return }
        struct Remote: Codable {
            let settings: [String: String]
            let updatedAt: [String: Int64]
        }
        guard let remote: Remote = try? await APIClient.shared.get("/api/auth/reader-settings", auth: true) else { return }
        for (key, value) in remote.settings {
            let serverTs = remote.updatedAt[key] ?? 0
            if (updatedAt[key] ?? 0) < serverTs {
                values[key] = value
                updatedAt[key] = serverTs
            }
        }
    }

    /// 防抖同步：停止改动 800ms 后推送一次 LWW 负载
    private func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, APIClient.shared.isAuthenticated else { return }
            let payload = ReaderSettingsPayload(settings: values, updatedAt: updatedAt)
            if let body = try? APIClient.shared.jsonBody(payload) {
                try? await APIClient.shared.requestVoid("PUT", "/api/auth/reader-settings", body: body, auth: true)
            }
        }
    }
}
