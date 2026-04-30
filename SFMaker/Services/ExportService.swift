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

        // Resolve the symbol image before opening a graphics context so failures are clean.
        var symbolImage: NSImage? = nil
        if config.imageSource == .sfSymbol {
            let symbolCfg = NSImage.SymbolConfiguration.make(from: config)
            guard let base = NSImage(systemSymbolName: config.symbolName, accessibilityDescription: nil),
                  let configured = base.withSymbolConfiguration(symbolCfg)
            else { throw ExportError.symbolNotFound(config.symbolName) }
            symbolImage = configured
        }

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

        if fileType == .jpeg {
            NSColor.white.setFill()
            bounds.fill()
        }
        NSColor(config.backgroundColor).withAlphaComponent(config.backgroundOpacity).setFill()
        bounds.fill()

        let padding = CGFloat(px) * 0.08
        let available = NSRect(x: padding, y: padding,
                               width: CGFloat(px) - padding * 2,
                               height: CGFloat(px) - padding * 2)

        if let sym = symbolImage {
            let fitRect = aspectFitRect(imageSize: sym.size, in: available)
            sym.draw(in: fitRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            drawEmoji(config.emojiText, in: available)
        }

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

        var symbolImage: NSImage? = nil
        if config.imageSource == .sfSymbol {
            let symbolCfg = NSImage.SymbolConfiguration.make(from: config)
            guard let base = NSImage(systemSymbolName: config.symbolName, accessibilityDescription: nil),
                  let configured = base.withSymbolConfiguration(symbolCfg)
            else { throw ExportError.symbolNotFound(config.symbolName) }
            symbolImage = configured
        }

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

        if let sym = symbolImage {
            let fitRect = aspectFitRect(imageSize: sym.size, in: available)
            sym.draw(in: fitRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            drawEmoji(config.emojiText, in: available)
        }

        ctx.endPDFPage()
        ctx.closePDF()
        NSGraphicsContext.restoreGraphicsState()

        try (pdfData as Data).write(to: url)
    }
}

// MARK: - Emoji rendering

func drawEmoji(_ text: String, in rect: NSRect) {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    let refFontSize: CGFloat = 1000
    let refAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: refFontSize)]
    let refStr = NSAttributedString(string: trimmed, attributes: refAttrs)
    let refMeasured = refStr.size()
    guard refMeasured.width > 0, refMeasured.height > 0 else { return }
    let scale = min(rect.width / refMeasured.width, rect.height / refMeasured.height)
    let font = NSFont.systemFont(ofSize: refFontSize * scale)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let str = NSAttributedString(string: trimmed, attributes: attrs)
    let size = str.size()
    str.draw(in: NSRect(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height
    ))
}

// MARK: - Geometry

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
