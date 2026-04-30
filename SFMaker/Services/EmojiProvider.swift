import Foundation

struct EmojiItem: Identifiable {
    let character: String
    let name: String
    var id: String { character }
}

struct EmojiProvider {
    static let shared = EmojiProvider()
    let emoji: [EmojiItem]

    private init() {
        let url = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/CoreEmoji.framework/Versions/A/Resources/en.lproj/AppleName.strings")
        guard let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil) as? [String: String]
        else { emoji = []; return }

        emoji = dict.map { EmojiItem(character: $0.key, name: $0.value) }
                    .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
