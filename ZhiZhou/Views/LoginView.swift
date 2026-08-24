import SwiftUI

/// 登录 / 注册（注册模式随服务端 register-status 动态切换）。
struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: Mode = .login
    @State private var username = ""
    @State private var password = ""
    @State private var invite = ""
    @State private var registerMode: RegisterMode = .invite
    @State private var busy = false
    @State private var errorMessage: String?

    enum Mode { case login, register }
    enum RegisterMode: String { case open, invite, closed }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $mode) {
                        Text("登录").tag(Mode.login)
                        Text("注册").tag(Mode.register)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $password)
                    if mode == .register && registerMode == .invite {
                        TextField("邀请码", text: $invite)
                    }
                    if mode == .register && registerMode == .closed {
                        Text("当前站点注册已关闭")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if busy {
                            ProgressView()
                        } else {
                            Text(mode == .login ? "登录" : "注册")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(busy || username.isEmpty || password.count < 8)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }
                }
            }
            .navigationTitle("知舟")
            .task { await fetchRegisterStatus() }
        }
    }

    private func fetchRegisterStatus() async {
        if let r: RegisterStatusResponse = try? await APIClient.shared.get("/api/auth/register-status") {
            registerMode = RegisterMode(rawValue: r.mode) ?? .invite
        }
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        errorMessage = nil
        do {
            if mode == .login {
                try await appState.login(username: username, password: password)
            } else {
                try await appState.register(username: username, password: password, invite: invite)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
