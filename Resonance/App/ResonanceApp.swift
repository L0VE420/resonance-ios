import SwiftData
import SwiftUI

@main
@MainActor
struct ResonanceApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.playback)
                .modelContainer(container.modelContainer)
                .tint(ResonanceTheme.accent)
        }
    }
}
