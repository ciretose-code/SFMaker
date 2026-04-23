import SwiftUI

struct ColorRowView: View {
    let label: String
    @Binding var color: Color
    var onClear: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker("", selection: $color, supportsOpacity: true)
                .labelsHidden()
            if let onClear {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
    }
}
