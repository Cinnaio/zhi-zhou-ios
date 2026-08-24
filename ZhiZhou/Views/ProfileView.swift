import SwiftUI

/// 个人中心：用户信息、阅读设置、服务器地址、退出登录。
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var serverConfig: ServerConfig

    @State private var showLogoutConfirm = false
    @State private var showReaderSettings = false
    @AppStorage("zhizhou.allowInvalidCert") private var allowInvalidCert = true

    var body: some View {
        Form {
            if let user = appState.user {
                Section {
                    HStack(spacing: 12) {
                        avatar(for: user)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.displayName)
                                .font(.headline)
                            Text("@\(user.username)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(user.displayBio)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("阅读") {
                Button {
                    showReaderSettings = true
                } label: {
                    Label("阅读设置", systemImage: "textformat.size")
                }
            }

            Section("服务器") {
                LabeledContent("当前地址", value: serverConfig.rawURL)
                NavigationLink {
                    ServerSetupView()
                } label: {
                    Label("修改服务器地址", systemImage: "server.rack")
                }
                Toggle("信任无效证书（开发用）", isOn: $allowInvalidCert)
            }

            Section {
                Button("退出登录", role: .destructive) {
                    showLogoutConfirm = true
                }
            }
        }
        .navigationTitle("我的")
        .sheet(isPresented: $showReaderSettings) {
            ReaderSettingsView()
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("确定退出登录？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                Task { await appState.logout() }
            }
        }
    }

    @ViewBuilder
    private func avatar(for user: User) -> some View {
        if let url = APIClient.shared.avatarURL(userId: user.id) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            AppTheme.primaryLight
            Image(systemName: "person.fill")
                .foregroundStyle(AppTheme.primary)
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }
}
