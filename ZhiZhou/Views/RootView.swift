import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var serverConfig: ServerConfig

    var body: some View {
        Group {
            if appState.isBooting {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在连接…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if !serverConfig.hasServer {
                ServerSetupView()
            } else if appState.user == nil {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isBooting)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("发现", systemImage: "books.vertical") }
            NavigationStack { BookshelfView() }
                .tabItem { Label("书架", systemImage: "bookmark") }
            NavigationStack { ProfileView() }
                .tabItem { Label("我的", systemImage: "person") }
        }
        .tint(AppTheme.primary)
    }
}
