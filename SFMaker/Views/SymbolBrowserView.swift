import SwiftUI
import AppKit

struct SymbolBrowserView: View {
    @EnvironmentObject var config: SymbolConfig
    @EnvironmentObject var symbolCache: SymbolCache
    @State private var searchText = ""
    @State private var emojiSearchText = ""

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

    private var filteredEmoji: [EmojiItem] {
        let all = EmojiProvider.shared.emoji
        guard emojiSearchText.count >= 2 else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(emojiSearchText) ||
            $0.character == emojiSearchText
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sourcePicker
            Divider()
            if config.imageSource == .sfSymbol {
                searchBar
                Divider()
                symbolGrid
            } else {
                emojiSearchBar
                Divider()
                emojiGrid
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Source picker

    private var sourcePicker: some View {
        Picker("Source", selection: $config.imageSource) {
            ForEach(SymbolConfig.ImageSource.allCases) { source in
                Text(source.rawValue).tag(source)
            }
        }
        .pickerStyle(.segmented)
        .padding(8)
        .labelsHidden()
    }

    // MARK: - SF Symbol browser

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

    // MARK: - Emoji browser

    private var emojiSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search emoji", text: $emojiSearchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    if let first = filteredEmoji.first {
                        config.emojiText = first.character
                    }
                }
            if !emojiSearchText.isEmpty {
                Button {
                    emojiSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }

    private var emojiGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76, maximum: 96))], spacing: 8) {
                    ForEach(filteredEmoji) { item in
                        EmojiCell(item: item, isSelected: config.emojiText == item.character)
                            .onTapGesture { config.emojiText = item.character }
                            .id(item.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: emojiSearchText) { _ in
                if let first = filteredEmoji.first {
                    proxy.scrollTo(first.id, anchor: .top)
                }
            }
        }
    }
}

// MARK: - Cells

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

private struct EmojiCell: View {
    let item: EmojiItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(item.character)
                .font(.system(size: 28))
                .frame(width: 60, height: 44)

            Text(item.name)
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
        .help(item.name)
        .contentShape(Rectangle())
    }
}
