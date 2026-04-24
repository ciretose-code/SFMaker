# SF Image Maker

Export any SF Symbol as a pixel-perfect image at any size.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## What it does

SF Image Maker lets you browse the full SF Symbols library, configure every visual property, and export a finished image — all without writing a line of code.

**Browse** — Search across all 4,600+ SF Symbols. The list is loaded directly from your installed SF Symbols app and stays current automatically.

**Configure** — Adjust weight (Ultra Light → Black), scale (Small / Medium / Large), and rendering mode (Monochrome, Hierarchical, Palette, Multicolor) with full color control for each layer.

**Background** — Pick any background color and opacity. Set opacity to zero for a transparent PNG.

**Export** — Choose from standard icon sizes for iOS, macOS, and watchOS, or enter a custom pixel dimension. Export as PNG, JPEG, TIFF, or PDF. Exports are pixel-exact — no Retina 2× scaling surprises.

## Requirements

- macOS 14 Sonoma or later
- [SF Symbols app](https://developer.apple.com/sf-symbols/) installed (for the full symbol list; a built-in fallback list is used if not present)

## Installation

Download the latest DMG from the [Releases](../../releases) page, open it, and drag **SF Image Maker** to your Applications folder.

## Usage

1. **Select a symbol** — browse the grid on the left or type to search (2+ characters)
2. **Configure appearance** — use the right panel to set weight, scale, rendering mode, colors, and background
3. **Set export options** — choose a size preset and format
4. **Export** — press **⌘E** or click the Export button, pick a save location, done

## Building from source

Requires Xcode 15+.

```bash
git clone https://github.com/ciretose-code/SFMaker.git
cd SFMaker
open SFMaker.xcodeproj
```

## Releasing

```bash
./Scripts/release.sh
```

Archives, notarizes, packages a DMG, and publishes a GitHub release in one step. See the script header for one-time notarization credential setup.
