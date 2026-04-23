import SwiftUI

@main
struct SFMakerApp: App {
    @StateObject private var config = SymbolConfig()
    @StateObject private var symbolCache = SymbolCache()

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
        }
    }
}
