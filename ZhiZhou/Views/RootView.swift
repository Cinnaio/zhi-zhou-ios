import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isBooting {
                BootView()
            } else if appState.user == nil {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isBooting)
    }
}

/// 启动连接页：暖纸面 + 品牌标识
struct BootView: View {
    var body: some View {
        ZStack {
            AppTheme.auroraBackground.ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.brandGradient)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .frame(width: 76, height: 76)
                .shadow(color: AppTheme.terracotta.opacity(0.3), radius: 14, y: 7)

                Text("知舟")
                    .font(serifFont(28, .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                ProgressView()
                    .controlSize(.regular)
                    .tint(AppTheme.primary)

                Text("正在连接…")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("发现", systemImage: "books.vertical") {
                NavigationStack { HomeView() }
            }
            Tab("书架", systemImage: "bookmark") {
                NavigationStack { BookshelfView() }
            }
            Tab("我的", systemImage: "person") {
                NavigationStack { ProfileView() }
            }
        }
        .tint(AppTheme.primary)
    }
}
