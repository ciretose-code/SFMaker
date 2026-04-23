import SwiftUI
import AppKit

struct SymbolBrowserView: View {
    @EnvironmentObject var config: SymbolConfig
    @EnvironmentObject var symbolCache: SymbolCache
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var exactMatch: String? {
        guard searchText.count >= 2,
              NSImage(systemSymbolName: searchText, accessibilityDescription: nil) != nil
        else { return nil }
        return searchText
    }

    private var searchResults: [String] {
        guard searchText.count >= 2 else { return [] }
        return symbolCache.symbols.filter {
            $0 != exactMatch && $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if searchText.count < 2 {
                recentsContent
            } else {
                searchContent
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Enter symbol name", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit {
                    if let match = exactMatch {
                        config.selectSymbol(match)
                        searchText = ""
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

    // MARK: - Recents

    private var recentsContent: some View {
        Group {
            if config.recentSymbols.isEmpty {
                emptyRecentsState
            } else {
                VStack(spacing: 0) {
                    recentsHeader
                    Divider()
                    recentsGrid
                }
            }
        }
    }

    private var recentsHeader: some View {
        HStack {
            Text("Recents")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear") { config.clearRecents() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var recentsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 80))], spacing: 8) {
                ForEach(config.recentSymbols, id: \.self) { name in
                    SymbolCell(name: name, isSelected: config.symbolName == name)
                        .onTapGesture { config.selectSymbol(name) }
                }
            }
            .padding(8)
        }
    }

    private var emptyRecentsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No recent symbols")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Type a symbol name above\nand press Return to add it.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Search results

    private var searchContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 80))], spacing: 8) {
                if let match = exactMatch {
                    exactMatchHeader(match)
                        .gridCellColumns(99)
                }

                ForEach(searchResults, id: \.self) { name in
                    SymbolCell(name: name, isSelected: config.symbolName == name)
                        .onTapGesture {
                            config.selectSymbol(name)
                            searchText = ""
                        }
                }

                if exactMatch == nil && searchResults.isEmpty {
                    noResultsHint.gridCellColumns(99)
                }
            }
            .padding(8)
        }
    }

    private func exactMatchHeader(_ match: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Exact match")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("↩ Return to select")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            SymbolCell(name: match, isSelected: config.symbolName == match, isExactMatch: true)
                .onTapGesture {
                    config.selectSymbol(match)
                    searchText = ""
                }
            if !searchResults.isEmpty {
                Divider().padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private var noResultsHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No symbol found for \"\(searchText)\"")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Try the full identifier, e.g.\nautostartstop.trianglebadge.exclamationmark")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
}

// MARK: - Cell

private struct SymbolCell: View {
    let name: String
    let isSelected: Bool
    var isExactMatch: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: name)
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
        }
        .frame(width: 60, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : (isExactMatch ? Color.accentColor.opacity(0.5) : Color.clear),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .help(name)
        .contentShape(Rectangle())
    }
}
