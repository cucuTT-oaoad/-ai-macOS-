import SwiftUI

@main
struct InfiniteStrikeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1024, minHeight: 640)
        }
        .defaultSize(width: 1280, height: 800)
    }
}
