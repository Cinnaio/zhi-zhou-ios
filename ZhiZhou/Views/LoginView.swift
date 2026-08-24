import SwiftUI

/// 登录 / 注册（注册模式随服务端 register-status 动态切换）。
/// iOS 26 Liquid Glass 风格：深色极光背景 + 玻璃卡片。
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
        ZStack {
            auroraBackdrop

            ScrollView {
                VStack(spacing: 26) {
                    header
                        .padding(.top, 96)
                    glassCard
                    serverNote
                }
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task { await fetchRegisterStatus() }
    }

    // MARK: - 背景（深色极光，为玻璃折射提供彩色底）

    private var auroraBackdrop: some View {
        ZStack {
            AppTheme.auroraBackground.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "4D9BFF").opacity(0.55))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: -150, y: -320)

            Circle()
                .fill(Color(hex: "B44DFF").opacity(0.5))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 170, y: -140)

            Circle()
                .fill(Color(hex: "FF6FA5").opacity(0.45))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -60, y: 330)

            Circle()
                .fill(Color(hex: "35E0C0").opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 110)
                .offset(x: 210, y: 360)
        }
    }

    // MARK: - 头部（品牌标识）

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFE0B8"), Color(hex: "F2B28C")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(hex: "6E4A34"))
            }
            .frame(width: 92, height: 92)
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)

            Text("知舟")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("登录后同步书架与阅读进度")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - 玻璃卡片

    private var glassCard: some View {
        VStack(spacing: 16) {
            modePicker

            glassField(icon: "person.fill", placeholder: "用户名", text: $username, isSecure: false)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            glassField(icon: "lock.fill", placeholder: "密码", text: $password, isSecure: true)

            if mode == .register && registerMode == .invite {
                glassField(icon: "key.fill", placeholder: "邀请码", text: $invite, isSecure: false)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if mode == .register && registerMode == .closed {
                Text("当前站点注册已关闭")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }

            submitButton

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "FFC2D4"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            segment(title: "登录", isSelected: mode == .login) { mode = .login }
            segment(title: "注册", isSelected: mode == .register) { mode = .register }
        }
        .padding(4)
        .background(.white.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }

    private func segment(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color(hex: "4A3A55") : Color.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    isSelected ? Color.white : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func glassField(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .foregroundStyle(.white)
            .tint(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .glassEffect(.thinMaterial, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            Group {
                if busy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(mode == .login ? "登 录" : "注 册")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.buttonGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy || username.isEmpty || password.count < 8)
        .opacity(busy || username.isEmpty || password.count < 8 ? 0.55 : 1)
        .shadow(color: Color(hex: "6E4A34").opacity(0.45), radius: 14, y: 7)
    }

    private var serverNote: some View {
        Label("连接知舟 · novel.mscraft.uk", systemImage: "server.rack")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.45))
    }

    // MARK: - 动作

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
