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

    /// The layout actually drawn for `paneCount` panes: it shrinks along its long side while there are fewer
    /// panes than slots (1×6 with 5 tabs shows 1×5, with 2 tabs 1×2) and grows back as tabs are added.
    /// The chosen layout itself never changes.
    public func effective(forPaneCount paneCount: Int) -> PaneLayout {
        let n = max(paneCount, 1)
        guard n < capacity else { return self }
        let cols = min(columns, n)
        let needed = Int((Double(n) / Double(cols)).rounded(.up))
        return PaneLayout(rows: min(rows, needed), columns: cols)
    }

    /// The smallest change to this layout that has room for `count` panes, growing along `axis`
    /// (`.right` adds columns, `.down` adds rows). Never exceeds `maxDimension` per side.
    public func growing(toFit count: Int, along axis: SplitAxis) -> PaneLayout {
        var r = rows, c = columns
        func full() -> Bool { r * c >= count }
        switch axis {
        case .right:
            if r == 1 { c = min(Self.maxDimension, max(c, count)) }
            while !full() && c < Self.maxDimension { c += 1 }
            while !full() && r < Self.maxDimension { r += 1 }
        case .down:
            if c == 1 { r = min(Self.maxDimension, max(r, count)) }
            while !full() && r < Self.maxDimension { r += 1 }
            while !full() && c < Self.maxDimension { c += 1 }
        }
        return PaneLayout(rows: r, columns: c)
    }

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
