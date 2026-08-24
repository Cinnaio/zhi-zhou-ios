import SwiftUI

@main
struct ZhiZhouApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var serverConfig = ServerConfig.shared
    @StateObject private var readerSettings = ReaderSettingsStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(serverConfig)
                .environmentObject(readerSettings)
        }
    }
}
