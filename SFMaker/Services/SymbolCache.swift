import Foundation

private let plistURL = URL(fileURLWithPath:
    "/Applications/SF Symbols.app/Contents/Resources/Metadata/name_availability.plist")
private let lastModKey = "sfSymbolsPlistModDate"

@MainActor
final class SymbolCache: ObservableObject {
    @Published private(set) var symbols: [String] = []
    @Published private(set) var source: Source = .empty

    enum Source {
        case empty, cache, live, fallback
    }

    private let cacheURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SFMaker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheURL = dir.appendingPathComponent("symbols.cache")

        // Load cache immediately so search is available before background check completes
        if let cached = loadFromCache() {
            symbols = cached
            source = .cache
        }

        Task { await checkForUpdates() }
    }

    // MARK: - Version check

    private func checkForUpdates() async {
        let fm = FileManager.default

        guard fm.fileExists(atPath: plistURL.path),
              let attrs = try? fm.attributesOfItem(atPath: plistURL.path),
              let plistMod = attrs[.modificationDate] as? Date
        else {
            if symbols.isEmpty { applyFallback() }
            return
        }

        let storedMod = UserDefaults.standard.object(forKey: lastModKey) as? Date

        // Only reload if plist is newer than our last load (or we've never loaded)
        if storedMod == nil || plistMod > storedMod! {
            if let names = await Task.detached(priority: .userInitiated, operation: {
                Self.loadFromPlist()
            }).value {
                symbols = names
                source = .live
                saveToCache(names)
                UserDefaults.standard.set(plistMod, forKey: lastModKey)
            }
        }

        if symbols.isEmpty { applyFallback() }
    }

    // MARK: - Plist loading (off main thread)

    private nonisolated static func loadFromPlist() -> [String]? {
        guard let data = try? Data(contentsOf: plistURL),
              let root = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil) as? [String: Any],
              let symbolsDict = root["symbols"] as? [String: Any]
        else { return nil }

        let names = symbolsDict.keys.sorted()
        return names.isEmpty ? nil : names
    }

    // MARK: - Cache (newline-separated text file)

    private func loadFromCache() -> [String]? {
        guard let text = try? String(contentsOf: cacheURL, encoding: .utf8) else { return nil }
        let names = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        return names.isEmpty ? nil : names
    }

    private func saveToCache(_ names: [String]) {
        let text = names.joined(separator: "\n")
        try? text.write(to: cacheURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Fallback

    private func applyFallback() {
        guard let url = Bundle.main.url(forResource: "fallback-symbols", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        let names = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted()
        if !names.isEmpty {
            symbols = names
            source = .fallback
        }
    }
}
