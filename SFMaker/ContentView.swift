import SwiftUI

struct ContentView: View {
    @EnvironmentObject var config: SymbolConfig

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
        .navigationTitle("SF Image Maker — \(config.symbolName)")
    }
}
