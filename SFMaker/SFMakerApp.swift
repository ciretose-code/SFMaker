import SwiftUI

@main
struct SFMakerApp: App {
    @StateObject private var config = SymbolConfig()
    @StateObject private var symbolCache = SymbolCache()
    @StateObject private var releaseCheckManager = ReleaseCheckManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(config)
                .environmentObject(symbolCache)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(releaseCheckManager.isChecking ? "Checking for Updates…" : "Check for Updates…") {
                    releaseCheckManager.checkForUpdates()
                }
                .disabled(releaseCheckManager.isChecking)
            }
        }
    }
}
