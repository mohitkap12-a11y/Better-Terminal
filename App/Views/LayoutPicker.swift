import SwiftUI
import BetterTerminalCore

/// Popover with mini diagrams, like the macOS window-tiling picker.
struct LayoutPicker: View {
    @Environment(AppModel.self) private var model
    @Binding var isPresented: Bool
    @State private var rows = 1
    @State private var cols = 2

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s3) {
            Text("Pane layout").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(64), spacing: Metrics.s2), count: 3),
                      spacing: Metrics.s2) {
                ForEach(PaneLayout.presets) { preset in
                    Button {
                        model.setLayout(preset); isPresented = false
                    } label: {
                        LayoutThumb(layout: preset, selected: preset == model.active?.layout)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.rows) rows by \(preset.columns) columns")
                    .help(preset.label)
                }
            }
            Divider()
            HStack {
                Stepper("Rows \(rows)", value: $rows, in: 1...PaneLayout.maxDimension)
                Stepper("Cols \(cols)", value: $cols, in: 1...PaneLayout.maxDimension)
            }
            .monospacedDigit()
            Button("Apply \(rows)×\(cols)") {
                model.setLayout(PaneLayout(rows: rows, columns: cols)); isPresented = false
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
        }
        .padding(Metrics.s4)
        .frame(width: 260)
        .onAppear {
            if let l = model.active?.layout { rows = l.rows; cols = l.columns }
        }
    }
}

struct LayoutThumb: View {
    @Environment(\.theme) private var theme
    let layout: PaneLayout
    let selected: Bool

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<layout.rows, id: \.self) { _ in
                GridRow {
                    ForEach(0..<layout.columns, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(selected ? theme.accent : Color.secondary.opacity(0.45))
                    }
                }
            }
        }
        .padding(4)
        .frame(width: 64, height: 44)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Metrics.radiusControl))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.radiusControl)
                .strokeBorder(selected ? theme.accent : .clear, lineWidth: 1.5)
        }
    }
}
