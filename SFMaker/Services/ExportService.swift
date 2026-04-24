import AppKit
import CoreGraphics

@MainActor
enum ExportService {
    static func export(config: SymbolConfig, to url: URL) throws {
        switch config.exportFormat {
        case .png:  try exportRaster(config: config, to: url, using: .png)
        case .jpeg: try exportRaster(config: config, to: url, using: .jpeg)
        case .tiff: try exportRaster(config: config, to: url, using: .tiff)
        case .pdf:  try exportPDF(config: config, to: url)
        }
    }

    // MARK: - Raster

    private static func exportRaster(
        config: SymbolConfig,
        to url: URL,
        using fileType: NSBitmapImageRep.FileType
    ) throws {
        let px = config.exportPixelSize
        let symbolCfg = NSImage.SymbolConfiguration.make(from: config)

        guard let base = NSImage(systemSymbolName: config.symbolName, accessibilityDescription: nil),
              let configured = base.withSymbolConfiguration(symbolCfg)
        else { throw ExportError.symbolNotFound(config.symbolName) }

        // Render directly into a bitmap at exact pixel dimensions — no lockFocus,
        // which would multiply by the screen's backing scale factor.
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { throw ExportError.renderFailed }
        rep.size = NSSize(width: px, height: px)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let bounds = NSRect(origin: .zero, size: NSSize(width: px, height: px))

        // JPEG has no alpha — fill white first
        if fileType == .jpeg {
            NSColor.white.setFill()
            bounds.fill()
        }
        let bgOpacity = fileType == .jpeg ? max(config.backgroundOpacity, 1.0) : config.backgroundOpacity
        NSColor(config.backgroundColor).withAlphaComponent(bgOpacity).setFill()
        bounds.fill()

        let padding = CGFloat(px) * 0.08
        let available = NSRect(x: padding, y: padding,
                               width: CGFloat(px) - padding * 2,
                               height: CGFloat(px) - padding * 2)
        let fitRect = aspectFitRect(imageSize: configured.size, in: available)
        configured.draw(in: fitRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: fileType, properties: jpegProperties(fileType))
        else { throw ExportError.renderFailed }

        try data.write(to: url)
    }

    private static func jpegProperties(_ fileType: NSBitmapImageRep.FileType) -> [NSBitmapImageRep.PropertyKey: Any] {
        guard fileType == .jpeg else { return [:] }
        return [.compressionFactor: 0.9]
    }

    // MARK: - PDF

    private static func exportPDF(config: SymbolConfig, to url: URL) throws {
        let px = config.exportPixelSize
        let targetSize = CGSize(width: px, height: px)
        let symbolCfg = NSImage.SymbolConfiguration.make(from: config)

        guard let base = NSImage(systemSymbolName: config.symbolName, accessibilityDescription: nil),
              let configured = base.withSymbolConfiguration(symbolCfg)
        else { throw ExportError.symbolNotFound(config.symbolName) }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw ExportError.renderFailed
        }

        var mediaBox = CGRect(origin: .zero, size: targetSize)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.renderFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

        ctx.beginPDFPage(nil)

        let bounds = CGRect(origin: .zero, size: targetSize)
        NSColor(config.backgroundColor).withAlphaComponent(config.backgroundOpacity).setFill()
        bounds.fill()

        let padding = CGFloat(px) * 0.08
        let available = NSRect(x: padding, y: padding,
                               width: CGFloat(px) - padding * 2,
                               height: CGFloat(px) - padding * 2)
        let fitRect = aspectFitRect(imageSize: configured.size, in: available)
        configured.draw(in: fitRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        ctx.endPDFPage()
        ctx.closePDF()
        NSGraphicsContext.restoreGraphicsState()

        try (pdfData as Data).write(to: url)
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case symbolNotFound(String)
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .symbolNotFound(let name): return "Symbol \"\(name)\" could not be rendered."
        case .renderFailed:             return "Export failed \u{2014} could not render image data."
        }
    }
}
