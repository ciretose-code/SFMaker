import SwiftUI
import UniformTypeIdentifiers
import Combine

private enum Keys {
    static let symbolName        = "symbolName"
    static let weight            = "weight"
    static let scale             = "scale"
    static let renderingMode     = "renderingMode"
    static let primaryColor      = "primaryColor"
    static let secondaryColor    = "secondaryColor"
    static let tertiaryColor     = "tertiaryColor"
    static let backgroundColor   = "backgroundColor"
    static let backgroundOpacity = "backgroundOpacity"
    static let exportWidth       = "exportWidth"
    static let exportHeight      = "exportHeight"
    static let lockAspectRatio   = "lockAspectRatio"
    static let exportFormat      = "exportFormat"
    static let recentSymbols     = "recentSymbols"
}

private let maxRecents = 50

@MainActor
final class SymbolConfig: ObservableObject {
    @Published var symbolName: String
    @Published var weight: SymbolWeight
    @Published var scale: SymbolScale
    @Published var renderingMode: RenderingMode
    @Published var primaryColor: Color
    @Published var secondaryColor: Color
    @Published var tertiaryColor: Color
    @Published var backgroundColor: Color
    @Published var backgroundOpacity: Double
    @Published var exportWidth: Int
    @Published var exportHeight: Int
    @Published var lockAspectRatio: Bool
    @Published var exportFormat: ExportFormat
    @Published var recentSymbols: [String]

    private var bag = Set<AnyCancellable>()

    init() {
        let ud = UserDefaults.standard
        symbolName       = ud.string(forKey: Keys.symbolName) ?? "star.fill"
        weight           = SymbolWeight(rawValue: ud.string(forKey: Keys.weight) ?? "") ?? .regular
        scale            = SymbolScale(rawValue: ud.string(forKey: Keys.scale) ?? "") ?? .medium
        renderingMode    = RenderingMode(rawValue: ud.string(forKey: Keys.renderingMode) ?? "") ?? .monochrome
        primaryColor     = Color(data: ud.data(forKey: Keys.primaryColor)) ?? .black
        secondaryColor   = Color(data: ud.data(forKey: Keys.secondaryColor)) ?? .accentColor
        tertiaryColor    = Color(data: ud.data(forKey: Keys.tertiaryColor)) ?? .gray
        backgroundColor  = Color(data: ud.data(forKey: Keys.backgroundColor)) ?? .white
        backgroundOpacity = ud.object(forKey: Keys.backgroundOpacity) as? Double ?? 0.0
        exportWidth      = ud.object(forKey: Keys.exportWidth) as? Int ?? 512
        exportHeight     = ud.object(forKey: Keys.exportHeight) as? Int ?? 512
        lockAspectRatio  = ud.object(forKey: Keys.lockAspectRatio) as? Bool ?? true
        exportFormat     = ExportFormat(rawValue: ud.string(forKey: Keys.exportFormat) ?? "") ?? .png
        recentSymbols    = ud.stringArray(forKey: Keys.recentSymbols) ?? []

        setupPersistence()
    }

    func selectSymbol(_ name: String) {
        symbolName = name
        recentSymbols.removeAll { $0 == name }
        recentSymbols.insert(name, at: 0)
        if recentSymbols.count > maxRecents {
            recentSymbols = Array(recentSymbols.prefix(maxRecents))
        }
    }

    func clearRecents() {
        recentSymbols = []
    }

    private func setupPersistence() {
        let ud = UserDefaults.standard
        $symbolName.dropFirst().sink { ud.set($0, forKey: Keys.symbolName) }.store(in: &bag)
        $weight.dropFirst().sink { ud.set($0.rawValue, forKey: Keys.weight) }.store(in: &bag)
        $scale.dropFirst().sink { ud.set($0.rawValue, forKey: Keys.scale) }.store(in: &bag)
        $renderingMode.dropFirst().sink { ud.set($0.rawValue, forKey: Keys.renderingMode) }.store(in: &bag)
        $primaryColor.dropFirst().sink { ud.set($0.toData(), forKey: Keys.primaryColor) }.store(in: &bag)
        $secondaryColor.dropFirst().sink { ud.set($0.toData(), forKey: Keys.secondaryColor) }.store(in: &bag)
        $tertiaryColor.dropFirst().sink { ud.set($0.toData(), forKey: Keys.tertiaryColor) }.store(in: &bag)
        $backgroundColor.dropFirst().sink { ud.set($0.toData(), forKey: Keys.backgroundColor) }.store(in: &bag)
        $backgroundOpacity.dropFirst().sink { ud.set($0, forKey: Keys.backgroundOpacity) }.store(in: &bag)
        $exportWidth.dropFirst().sink { ud.set($0, forKey: Keys.exportWidth) }.store(in: &bag)
        $exportHeight.dropFirst().sink { ud.set($0, forKey: Keys.exportHeight) }.store(in: &bag)
        $lockAspectRatio.dropFirst().sink { ud.set($0, forKey: Keys.lockAspectRatio) }.store(in: &bag)
        $exportFormat.dropFirst().sink { ud.set($0.rawValue, forKey: Keys.exportFormat) }.store(in: &bag)
        $recentSymbols.dropFirst().sink { ud.set($0, forKey: Keys.recentSymbols) }.store(in: &bag)
    }

    // MARK: - Nested types

    enum SymbolWeight: String, CaseIterable, Identifiable {
        case ultraLight = "Ultra Light"
        case thin = "Thin"
        case light = "Light"
        case regular = "Regular"
        case medium = "Medium"
        case semibold = "Semibold"
        case bold = "Bold"
        case heavy = "Heavy"
        case black = "Black"

        var id: String { rawValue }

        var nsWeight: NSFont.Weight {
            switch self {
            case .ultraLight: return .ultraLight
            case .thin:       return .thin
            case .light:      return .light
            case .regular:    return .regular
            case .medium:     return .medium
            case .semibold:   return .semibold
            case .bold:       return .bold
            case .heavy:      return .heavy
            case .black:      return .black
            }
        }
    }

    enum SymbolScale: String, CaseIterable, Identifiable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        var id: String { rawValue }

        var nsScale: NSImage.SymbolScale {
            switch self {
            case .small:  return .small
            case .medium: return .medium
            case .large:  return .large
            }
        }
    }

    enum RenderingMode: String, CaseIterable, Identifiable {
        case monochrome   = "Monochrome"
        case hierarchical = "Hierarchical"
        case palette      = "Palette"
        case multicolor   = "Multicolor"

        var id: String { rawValue }
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case png  = "PNG"
        case jpeg = "JPEG"
        case tiff = "TIFF"
        case pdf  = "PDF"

        var id: String { rawValue }
        var fileExtension: String { rawValue.lowercased() }

        var utType: UTType {
            switch self {
            case .png:  return .png
            case .jpeg: return .jpeg
            case .tiff: return .tiff
            case .pdf:  return .pdf
            }
        }
    }
}

// MARK: - Color serialization

private extension Color {
    init?(data: Data?) {
        guard let data,
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        else { return nil }
        self = Color(nsColor)
    }

    func toData() -> Data? {
        try? NSKeyedArchiver.archivedData(
            withRootObject: NSColor(self),
            requiringSecureCoding: true
        )
    }
}
