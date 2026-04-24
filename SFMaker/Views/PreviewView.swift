import SwiftUI
import AppKit

struct PreviewView: View {
    @EnvironmentObject var config: SymbolConfig

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            SymbolImageView()
                .frame(maxWidth: 360, maxHeight: 360)
                .padding()
            Text(config.symbolName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(config.exportPixelSize) × \(config.exportPixelSize) px  ·  \(config.exportFormat.rawValue)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SymbolImageView: NSViewRepresentable {
    @EnvironmentObject var config: SymbolConfig

    func makeNSView(context: Context) -> CheckerboardImageView {
        let view = CheckerboardImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        update(view)
        return view
    }

    func updateNSView(_ nsView: CheckerboardImageView, context: Context) {
        update(nsView)
    }

    private func update(_ view: CheckerboardImageView) {
        let symbolCfg = NSImage.SymbolConfiguration.make(from: config)
        guard let base = NSImage(systemSymbolName: config.symbolName, accessibilityDescription: nil),
              let configured = base.withSymbolConfiguration(symbolCfg)
        else { return }

        let px = 300
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        rep.size = NSSize(width: px, height: px)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let bounds = NSRect(origin: .zero, size: NSSize(width: px, height: px))
        NSColor(config.backgroundColor).withAlphaComponent(config.backgroundOpacity).setFill()
        bounds.fill()

        let padding: CGFloat = 24
        let available = NSRect(x: padding, y: padding,
                               width: CGFloat(px) - padding * 2,
                               height: CGFloat(px) - padding * 2)
        let fitRect = aspectFitRect(imageSize: configured.size, in: available)
        configured.draw(in: fitRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        let rendered = NSImage(size: NSSize(width: px, height: px))
        rendered.addRepresentation(rep)
        view.image = rendered
        view.showsCheckerboard = config.backgroundOpacity < 0.01
    }
}

final class CheckerboardImageView: NSImageView {
    var showsCheckerboard = true {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        if showsCheckerboard {
            drawCheckerboard(in: bounds)
        }
        super.draw(dirtyRect)
    }

    private func drawCheckerboard(in rect: NSRect) {
        let tileSize: CGFloat = 8
        var row = 0
        var y: CGFloat = 0
        while y < rect.height {
            var col = 0
            var x: CGFloat = 0
            while x < rect.width {
                let isLight = (row + col) % 2 == 0
                (isLight ? NSColor(white: 0.85, alpha: 1) : NSColor(white: 0.7, alpha: 1)).setFill()
                NSRect(x: x, y: y, width: tileSize, height: tileSize).fill()
                x += tileSize
                col += 1
            }
            y += tileSize
            row += 1
        }
    }
}

func aspectFitRect(imageSize: NSSize, in rect: NSRect) -> NSRect {
    guard imageSize.width > 0, imageSize.height > 0 else { return rect }
    let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
    let w = imageSize.width * scale
    let h = imageSize.height * scale
    return NSRect(
        x: rect.minX + (rect.width - w) / 2,
        y: rect.minY + (rect.height - h) / 2,
        width: w, height: h
    )
}

extension NSImage.SymbolConfiguration {
    @MainActor
    static func make(from config: SymbolConfig) -> NSImage.SymbolConfiguration {
        var cfg = NSImage.SymbolConfiguration(
            pointSize: 200,
            weight: config.weight.nsWeight,
            scale: config.scale.nsScale
        )

        switch config.renderingMode {
        case .monochrome:
            cfg = cfg.applying(.preferringMonochrome())
        case .hierarchical:
            let color = NSColor(config.primaryColor)
            cfg = cfg.applying(.preferringHierarchical())
            cfg = cfg.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        case .palette:
            let colors = [
                NSColor(config.primaryColor),
                NSColor(config.secondaryColor),
                NSColor(config.tertiaryColor)
            ]
            cfg = cfg.applying(NSImage.SymbolConfiguration(paletteColors: colors))
        case .multicolor:
            cfg = cfg.applying(.preferringMulticolor())
        }

        return cfg
    }
}
