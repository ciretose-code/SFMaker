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
        let targetSize = NSSize(width: config.exportWidth, height: config.exportHeight)
        let symbolCfg = NSImage.SymbolConfiguration.make(from: config)

        guard let base = NSImage(systemSymbolName: config.symbolName, accessibilityDescription: nil),
              let configured = base.withSymbolConfiguration(symbolCfg)
        else { throw ExportError.symbolNotFound(config.symbolName) }

        let offscreen = NSImage(size: targetSize)
        offscreen.lockFocus()

        // JPEG has no alpha channel — force white base then overlay bg color
        if fileType == .jpeg {
            NSColor.white.setFill()
            NSRect(origin: .zero, size: targetSize).fill()
        }
        let bgOpacity = fileType == .jpeg ? max(config.backgroundOpacity, 1.0) : config.backgroundOpacity
        let bgColor = NSColor(config.backgroundColor).withAlphaComponent(bgOpacity)
        bgColor.setFill()
        NSRect(origin: .zero, size: targetSize).fill()

        // Symbol aspect-fit centered within padded area
        let padding = targetSize.width * 0.08
        let available = NSRect(
            x: padding, y: padding,
            width: targetSize.width - padding * 2,
            height: targetSize.height - padding * 2
        )
        let fitRect = aspectFitRect(imageSize: configured.size, in: available)
        configured.draw(in: fitRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        offscreen.unlockFocus()

        guard let tiffData = offscreen.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let data = rep.representation(using: fileType, properties: jpegProperties(fileType))
        else { throw ExportError.renderFailed }

        try data.write(to: url)
    }

    private static func jpegProperties(_ fileType: NSBitmapImageRep.FileType) -> [NSBitmapImageRep.PropertyKey: Any] {
        guard fileType == .jpeg else { return [:] }
        return [.compressionFactor: 0.9]
    }

    // MARK: - PDF

    private static func exportPDF(config: SymbolConfig, to url: URL) throws {
        let targetSize = CGSize(width: config.exportWidth, height: config.exportHeight)
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

        let bgColor = NSColor(config.backgroundColor).withAlphaComponent(config.backgroundOpacity)
        bgColor.setFill()
        CGRect(origin: .zero, size: targetSize).fill()

        let padding = targetSize.width * 0.08
        let available = NSRect(
            x: padding, y: padding,
            width: targetSize.width - padding * 2,
            height: targetSize.height - padding * 2
        )
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
