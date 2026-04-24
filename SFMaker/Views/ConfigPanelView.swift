import SwiftUI

struct ConfigPanelView: View {
    @EnvironmentObject var config: SymbolConfig

    var body: some View {
        Form {
            symbolSection
            renderingSection
            backgroundSection
            exportSection
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }

    // MARK: - Symbol

    private var symbolSection: some View {
        Section("Symbol") {
            LabeledContent("Name") {
                Text(config.symbolName)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Picker("Weight", selection: $config.weight) {
                ForEach(SymbolConfig.SymbolWeight.allCases) { w in
                    Text(w.rawValue).tag(w)
                }
            }

            Picker("Scale", selection: $config.scale) {
                ForEach(SymbolConfig.SymbolScale.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
        }
    }

    // MARK: - Rendering

    private var renderingSection: some View {
        Section("Rendering") {
            Picker("Mode", selection: $config.renderingMode) {
                ForEach(SymbolConfig.RenderingMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            ColorRowView(label: "Primary", color: $config.primaryColor) {
                config.primaryColor = .black
            }

            ColorRowView(label: "Secondary", color: $config.secondaryColor) {
                config.secondaryColor = .accentColor
            }
            .disabled(config.renderingMode != .palette)
            .opacity(config.renderingMode == .palette ? 1 : 0.3)

            ColorRowView(label: "Tertiary", color: $config.tertiaryColor) {
                config.tertiaryColor = .gray
            }
            .disabled(config.renderingMode != .palette)
            .opacity(config.renderingMode == .palette ? 1 : 0.3)
        }
    }

    // MARK: - Background

    private var backgroundSection: some View {
        Section("Background") {
            ColorRowView(label: "Color", color: $config.backgroundColor) {
                config.backgroundColor = .white
            }

            HStack {
                Text("Opacity")
                Slider(value: $config.backgroundOpacity, in: 0...1)
                Text("\(Int(config.backgroundOpacity * 100))%")
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }

            Button("Set Transparent") {
                config.backgroundOpacity = 0
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        Section("Export") {
            Picker("Size", selection: $config.exportPreset) {
                ForEach(SymbolConfig.ExportPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }

            if config.exportPreset == .custom {
                HStack {
                    TextField("Pixels", value: $config.customSize, format: .number)
                    Text("px × \(config.customSize) px")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } else {
                Picker("Scale", selection: $config.exportScale) {
                    ForEach(SymbolConfig.ExportScale.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Output") {
                    Text("\(config.exportPixelSize) × \(config.exportPixelSize) px")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            Picker("Format", selection: $config.exportFormat) {
                ForEach(SymbolConfig.ExportFormat.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)

            Button(action: export) {
                Label("Export…", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("e", modifiers: .command)
        }
    }

    // MARK: - Actions

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [config.exportFormat.utType]
        let scaleSuffix = config.exportPreset == .custom ? "" : config.exportScale.rawValue
        panel.nameFieldStringValue = "\(config.symbolName)\(scaleSuffix).\(config.exportFormat.fileExtension)"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try ExportService.export(config: config, to: url)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
}
