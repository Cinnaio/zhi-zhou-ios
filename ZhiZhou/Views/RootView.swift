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

/// 启动连接页：深色极光 + 加载指示
struct BootView: View {
    var body: some View {
        ZStack {
            AppTheme.auroraBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("正在连接…")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
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
