import Foundation

/// Grid arrangement of terminal panes inside a workspace.
/// rows x columns; new panes fill row-major and follow this layout.
public struct PaneLayout: Codable, Hashable, Sendable, Identifiable {
    public var rows: Int
    public var columns: Int

    public var id: String { "\(rows)x\(columns)" }
    public var capacity: Int { rows * columns }
    public var label: String { "\(rows)×\(columns)" }

    public init(rows: Int, columns: Int) {
        self.rows = max(1, min(rows, Self.maxDimension))
        self.columns = max(1, min(columns, Self.maxDimension))
    }

    public static let maxDimension = 6

    public static let single = PaneLayout(rows: 1, columns: 1)

    /// Presets shown in the layout picker popover.
    public static let presets: [PaneLayout] = [
        .init(rows: 1, columns: 1),
        .init(rows: 1, columns: 2), .init(rows: 2, columns: 1),
        .init(rows: 1, columns: 3), .init(rows: 3, columns: 1),
        .init(rows: 2, columns: 2),
        .init(rows: 2, columns: 3), .init(rows: 3, columns: 2),
        .init(rows: 3, columns: 3)
    ]

    /// Grid cell for the pane at `index` (row-major). Panes beyond capacity
    /// spill into extra rows so no pane is ever hidden.
    public func cell(forPaneAt index: Int) -> (row: Int, column: Int) {
        let i = max(0, index)
        return (i / columns, i % columns)
    }

    /// Number of rows needed to show `paneCount` panes.
    public func rowsNeeded(forPaneCount paneCount: Int) -> Int {
        max(rows, Int((Double(max(paneCount, 1)) / Double(columns)).rounded(.up)))
    }
}
