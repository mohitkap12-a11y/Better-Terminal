import Foundation

public enum PaneDirection: Sendable { case left, right, up, down }

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

    /// The pane reached by moving one step from `index` in `direction`, or nil at an edge.
    /// Panes fill row-major, so the last row may be shorter: moving down into it lands on its last pane.
    public func neighbor(of index: Int, _ direction: PaneDirection, paneCount: Int) -> Int? {
        guard paneCount > 0, (0..<paneCount).contains(index) else { return nil }
        let row = index / columns, col = index % columns
        switch direction {
        case .left:
            return col > 0 ? index - 1 : nil
        case .right:
            return col < columns - 1 && index + 1 < paneCount ? index + 1 : nil
        case .up:
            return row > 0 ? index - columns : nil
        case .down:
            let target = index + columns
            if target < paneCount { return target }
            let lastRow = (paneCount - 1) / columns
            return row < lastRow ? paneCount - 1 : nil
        }
    }
}
