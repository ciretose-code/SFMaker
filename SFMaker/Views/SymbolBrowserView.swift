import SwiftUI
import AppKit

struct SymbolBrowserView: View {
    @EnvironmentObject var config: SymbolConfig
    @EnvironmentObject var symbolCache: SymbolCache
    @State private var searchText = ""

    private var displayedSymbols: [String] {
        if searchText.count < 2 { return symbolCache.symbols }
        return symbolCache.symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var exactMatch: String? {
        guard searchText.count >= 2,
              NSImage(systemSymbolName: searchText, accessibilityDescription: nil) != nil,
              !symbolCache.symbols.contains(searchText)
        else { return nil }
        return searchText
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            symbolGrid
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search symbols", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    if let match = exactMatch {
                        config.symbolName = match
                        searchText = ""
                    } else if let first = displayedSymbols.first {
                        config.symbolName = first
                    }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }

    private var symbolGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76, maximum: 96))], spacing: 8) {
                    if let match = exactMatch {
                        SymbolCell(name: match, isSelected: config.symbolName == match)
                            .onTapGesture { config.symbolName = match; searchText = "" }
                            .id("exact")
                    }
                    ForEach(displayedSymbols, id: \.self) { name in
                        SymbolCell(name: name, isSelected: config.symbolName == name)
                            .onTapGesture { config.symbolName = name }
                            .id(name)
                    }
                }
                .padding(8)
            }
            .onChange(of: searchText) { _ in
                if let first = displayedSymbols.first {
                    proxy.scrollTo(first, anchor: .top)
                }
            }
        }
    }
}

private struct SymbolCell: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: name)
                .font(.system(size: 24))
                .frame(width: 60, height: 44)

            Text(name)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 68)
        }
        .padding(.vertical, 4)
        .frame(width: 76)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .help(name)
        .contentShape(Rectangle())
    }
}
