import SwiftUI

/// 阅读设置面板：字号/字体/行距/主题，改动即时生效并同步服务器。
struct ReaderSettingsView: View {
    @EnvironmentObject private var settings: ReaderSettingsStore
    @Environment(\.dismiss) private var dismiss

    private let fontLevels = ["0", "1", "2", "3", "4", "5"]

    var body: some View {
        NavigationStack {
            Form {
                Section("字号") {
                    Stepper(
                        "字号：第 \(settings.fontSizeIndex + 1) 档",
                        value: Binding(
                            get: { settings.fontSizeIndex },
                            set: { settings.set("fontSize", fontLevels[$0]) }
                        ),
                        in: 0...5
                    )
                }

                Section("字体") {
                    Picker("字体", selection: Binding(
                        get: { settings.useSerif ? "serif" : "sans" },
                        set: { settings.set("fontFamily", $0) }
                    )) {
                        Text("衬线（宋体感）").tag("serif")
                        Text("无衬线（黑体感）").tag("sans")
                    }
                    .pickerStyle(.segmented)
                }

                Section("行距") {
                    Picker("行距", selection: Binding(
                        get: { settings.values["readerLineHeight"] ?? "1.95" },
                        set: { settings.set("readerLineHeight", $0) }
                    )) {
                        Text("紧凑").tag("1.75")
                        Text("标准").tag("1.95")
                        Text("宽松").tag("2.15")
                    }
                    .pickerStyle(.segmented)
                }

                Section("主题") {
                    Picker("主题", selection: Binding(
                        get: { settings.themeName },
                        set: { settings.set("readerTheme", $0) }
                    )) {
                        Text("纸面").tag("default")
                        Text("护眼").tag("eye")
                        Text("羊皮纸").tag("paper")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        Text("内容模式")
                        Spacer()
                        Text(settings.contentMode == "adult" ? "成人" : "安全")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("与 Web 端阅读设置互通（LWW 合并）。")
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
