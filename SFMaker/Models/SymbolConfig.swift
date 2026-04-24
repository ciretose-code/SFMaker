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
    static let exportPreset      = "exportPreset"
    static let exportScale       = "exportScale"
    static let customSize        = "customSize"
    static let exportFormat      = "exportFormat"
}

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
    @Published var exportPreset: ExportPreset
    @Published var exportScale: ExportScale
    @Published var customSize: Int
    @Published var exportFormat: ExportFormat

    var exportPixelSize: Int {
        exportPreset == .custom ? customSize : exportPreset.pointSize * exportScale.factor
    }

    private var bag = Set<AnyCancellable>()

    init() {
        let ud = UserDefaults.standard
        symbolName        = ud.string(forKey: Keys.symbolName) ?? "star.fill"
        weight            = SymbolWeight(rawValue: ud.string(forKey: Keys.weight) ?? "") ?? .regular
        scale             = SymbolScale(rawValue: ud.string(forKey: Keys.scale) ?? "") ?? .medium
        renderingMode     = RenderingMode(rawValue: ud.string(forKey: Keys.renderingMode) ?? "") ?? .monochrome
        primaryColor      = Color(data: ud.data(forKey: Keys.primaryColor)) ?? .black
        secondaryColor    = Color(data: ud.data(forKey: Keys.secondaryColor)) ?? .accentColor
        tertiaryColor     = Color(data: ud.data(forKey: Keys.tertiaryColor)) ?? .gray
        backgroundColor   = Color(data: ud.data(forKey: Keys.backgroundColor)) ?? .white
        backgroundOpacity = ud.object(forKey: Keys.backgroundOpacity) as? Double ?? 0.0
        exportPreset      = ExportPreset(rawValue: ud.string(forKey: Keys.exportPreset) ?? "") ?? .ios1024
        exportScale       = ExportScale(rawValue: ud.string(forKey: Keys.exportScale) ?? "") ?? .x1
        customSize        = ud.object(forKey: Keys.customSize) as? Int ?? 512
        exportFormat      = ExportFormat(rawValue: ud.string(forKey: Keys.exportFormat) ?? "") ?? .png

        setupPersistence()
    }

    private func setupPersistence() {
        let ud = UserDefaults.standard
        $symbolName.dropFirst().sink        { ud.set($0, forKey: Keys.symbolName) }.store(in: &bag)
        $weight.dropFirst().sink            { ud.set($0.rawValue, forKey: Keys.weight) }.store(in: &bag)
        $scale.dropFirst().sink             { ud.set($0.rawValue, forKey: Keys.scale) }.store(in: &bag)
        $renderingMode.dropFirst().sink     { ud.set($0.rawValue, forKey: Keys.renderingMode) }.store(in: &bag)
        $primaryColor.dropFirst().sink      { ud.set($0.toData(), forKey: Keys.primaryColor) }.store(in: &bag)
        $secondaryColor.dropFirst().sink    { ud.set($0.toData(), forKey: Keys.secondaryColor) }.store(in: &bag)
        $tertiaryColor.dropFirst().sink     { ud.set($0.toData(), forKey: Keys.tertiaryColor) }.store(in: &bag)
        $backgroundColor.dropFirst().sink   { ud.set($0.toData(), forKey: Keys.backgroundColor) }.store(in: &bag)
        $backgroundOpacity.dropFirst().sink { ud.set($0, forKey: Keys.backgroundOpacity) }.store(in: &bag)
        $exportPreset.dropFirst().sink      { ud.set($0.rawValue, forKey: Keys.exportPreset) }.store(in: &bag)
        $exportScale.dropFirst().sink       { ud.set($0.rawValue, forKey: Keys.exportScale) }.store(in: &bag)
        $customSize.dropFirst().sink        { ud.set($0, forKey: Keys.customSize) }.store(in: &bag)
        $exportFormat.dropFirst().sink      { ud.set($0.rawValue, forKey: Keys.exportFormat) }.store(in: &bag)
    }

    // MARK: - Nested types

    enum SymbolWeight: String, CaseIterable, Identifiable {
        case ultraLight = "Ultra Light"
        case thin       = "Thin"
        case light      = "Light"
        case regular    = "Regular"
        case medium     = "Medium"
        case semibold   = "Semibold"
        case bold       = "Bold"
        case heavy      = "Heavy"
        case black      = "Black"

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
        case small  = "Small"
        case medium = "Medium"
        case large  = "Large"

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

    enum ExportPreset: String, CaseIterable, Identifiable {
        // iOS / iPadOS
        case ios20    = "iOS 20pt — Notifications"
        case ios29    = "iOS 29pt — Settings"
        case ios40    = "iOS 40pt — Spotlight"
        case ios60    = "iOS 60pt — App Icon"
        case ios76    = "iOS 76pt — iPad App Icon"
        case ios835   = "iOS 83.5pt — iPad Pro App Icon"
        case ios1024  = "iOS 1024pt — App Store"
        // macOS
        case mac16    = "macOS 16pt"
        case mac32    = "macOS 32pt"
        case mac128   = "macOS 128pt"
        case mac256   = "macOS 256pt"
        case mac512   = "macOS 512pt"
        case mac1024  = "macOS 1024pt — App Store"
        // watchOS
        case watch40  = "watchOS 40pt"
        case watch44  = "watchOS 44pt"
        case watch50  = "watchOS 50pt"
        case watch86  = "watchOS 86pt"
        case watch98  = "watchOS 98pt"
        case watch108 = "watchOS 108pt"
        // Custom
        case custom   = "Custom"

        var id: String { rawValue }

        var pointSize: Int {
            switch self {
            case .ios20:    return 20
            case .ios29:    return 29
            case .ios40:    return 40
            case .ios60:    return 60
            case .ios76:    return 76
            case .ios835:   return 84   // rounded from 83.5
            case .ios1024:  return 1024
            case .mac16:    return 16
            case .mac32:    return 32
            case .mac128:   return 128
            case .mac256:   return 256
            case .mac512:   return 512
            case .mac1024:  return 1024
            case .watch40:  return 40
            case .watch44:  return 44
            case .watch50:  return 50
            case .watch86:  return 86
            case .watch98:  return 98
            case .watch108: return 108
            case .custom:   return 0
            }
        }
    }

    enum ExportScale: String, CaseIterable, Identifiable {
        case x1 = "@1x"
        case x2 = "@2x"
        case x3 = "@3x"

        var id: String { rawValue }

        var factor: Int {
            switch self {
            case .x1: return 1
            case .x2: return 2
            case .x3: return 3
            }
        }
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
