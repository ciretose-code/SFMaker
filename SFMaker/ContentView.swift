import SwiftUI

struct ContentView: View {
    @EnvironmentObject var config: SymbolConfig
    @EnvironmentObject var symbolCache: SymbolCache

    var body: some View {
        NavigationSplitView {
            SymbolBrowserView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } content: {
            PreviewView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 400)
        } detail: {
            ConfigPanelView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        }
        .navigationTitle(navigationTitle)
        .task { await symbolCache.checkForUpdates() }
    }

    private var navigationTitle: String {
        let suffix = config.imageSource == .sfSymbol
            ? config.symbolName
            : (config.emojiText.isEmpty ? "Emoji" : config.emojiText)
        return "SF Image Maker — \(suffix)"
    }
}
