import SwiftUI

/// 首次启动 / 修改服务器地址：填写知舟实例地址并测试连通性。
struct ServerSetupView: View {
    @EnvironmentObject private var serverConfig: ServerConfig
    @State private var urlText = ""
    @State private var testing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://reader.example.com", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("知舟服务器地址")
                } footer: {
                    Text("填写你部署的知舟实例地址。App 会自动拼上 /api 前缀访问接口。\n内网自托管可用 http:// 开头；公网请用 https://。")
                }

                Section {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        if testing {
                            ProgressView()
                        } else {
                            Text("测试连接")
                        }
                    }
                    .disabled(trimmed.isEmpty || testing)

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(message.hasPrefix("✅") ? AppTheme.success : AppTheme.danger)
                    }
                }

                Section {
                    Button("保存") {
                        serverConfig.rawURL = urlText
                        if serverConfig.baseURL == nil {
                            message = "地址格式不正确，请包含 http(s)://"
                        }
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
            .navigationTitle("欢迎使用知舟")
            .onAppear {
                if urlText.isEmpty { urlText = serverConfig.rawURL }
            }
        }
    }

    private var trimmed: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func testConnection() async {
        testing = true
        defer { testing = false }
        serverConfig.rawURL = urlText
        do {
            let r: HealthResponse = try await APIClient.shared.get("/api/health")
            message = "✅ 连接成功：\(r.name)"
        } catch {
            message = "❌ \(error.localizedDescription)"
        }
    }
}
