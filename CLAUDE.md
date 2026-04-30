# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

**SF Image Maker** — a macOS 14+ SwiftUI app that exports SF Symbols as pixel-perfect images (PNG, JPEG, TIFF, PDF). Users browse 4,600+ symbols, configure weight/scale/rendering/colors/background, choose an export preset or custom size, and export via ⌘E.

## Build & release

Open in Xcode 15+ (no command-line build needed for development):
```bash
open SFMaker.xcodeproj
```

To cut a release (archive → notarize → DMG → GitHub release):
```bash
./Scripts/release.sh
```
One-time notarization setup is documented in the script header. The notary keychain profile name is `sfmaker-notary`.

## Architecture

Single `WindowGroup`, minimum size 900×600. Two shared `@StateObject`s injected as environment objects from `SFMakerApp`:

- **`SymbolConfig`** (`Models/SymbolConfig.swift`) — the entire app's state. All configuration fields are `@Published`, persisted automatically to `UserDefaults` via Combine sinks. All domain enums (`SymbolWeight`, `SymbolScale`, `RenderingMode`, `ExportPreset`, `ExportScale`, `ExportFormat`) are nested inside this class. The `NSImage.SymbolConfiguration.make(from:)` extension (at the bottom of this file) converts `SymbolConfig` state into an `NSImage.SymbolConfiguration` for rendering.

- **`SymbolCache`** (`Services/SymbolCache.swift`) — loads symbol names from the installed SF Symbols app's plist at `/Applications/SF Symbols.app/Contents/Resources/Metadata/name_availability.plist`. Caches the list as a newline-separated text file in `~/Library/Application Support/SFMaker/symbols.cache`. Falls back to the bundled `Resources/fallback-symbols.txt` if the SF Symbols app is absent.

Three-column `NavigationSplitView` in `ContentView`:
1. **`SymbolBrowserView`** (left) — searchable `LazyVGrid` of symbol cells. Filters `symbolCache.symbols` on 2+ characters. Exact-match detection lets users type a symbol name not yet in the list.
2. **`PreviewView`** (center) — live 300×300px bitmap preview. Uses `CheckerboardImageView` (an `NSImageView` subclass) which draws a grey checkerboard whenever `backgroundOpacity < 0.01`.
3. **`ConfigPanelView`** (right) — grouped `Form` with sections for Symbol, Rendering, Background, and Export. Export button triggers `NSSavePanel` then calls `ExportService`.

**`ExportService`** (`Services/ExportService.swift`) — static enum, no state. Renders to `NSBitmapImageRep` directly (avoids `lockFocus` which would multiply by the screen's backing scale factor). PDF export goes through `CGContext`/`CGDataConsumer`. Both paths apply 8% padding around the symbol and `aspectFitRect()` centering. JPEG always gets a white base fill before the background layer.

## Adding an emoji image source

The intended next feature is supporting emoji as an image source alongside SF Symbols. Key design points:

- **`SymbolConfig`** needs a new source discriminator (e.g. `enum ImageSource { case sfSymbol(String), emoji(String) }`) replacing the bare `symbolName: String`. Update `UserDefaults` persistence accordingly.
- **`ExportService`** needs an emoji rendering path: draw the emoji string into an `NSBitmapImageRep` using `NSAttributedString` with a large font size, centered in the padded bounds.
- **`PreviewView`** / `SymbolImageView` needs to handle the emoji case — `NSImage(systemSymbolName:)` only works for SF Symbols.
- **`SymbolBrowserView`** may need a mode toggle or separate tab to switch between SF Symbol browsing and emoji input.
- The `NSImage.SymbolConfiguration.make(from:)` extension and all SF Symbol weight/scale/rendering options are irrelevant for emoji — the config panel should hide or disable those sections when the source is emoji.
