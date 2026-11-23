import Foundation

/// App state: one JSON file, atomic writes. History: append-only JSONL per tab
/// (crash-safe, cheap appends, survives reboot). Commands only, no output.
public final class WorkspaceStore: @unchecked Sendable {
    public let directory: URL
    private let queue = DispatchQueue(label: "better-terminal.store")
    private let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }()
    private let lineEncoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
    }

    /// ~/Library/Application Support/BetterTerminal
    public static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BetterTerminal", isDirectory: true)
    }

    private var stateURL: URL { directory.appendingPathComponent("state.json") }
    private var historyDir: URL { directory.appendingPathComponent("history", isDirectory: true) }
    private func historyURL(_ tab: UUID) -> URL { historyDir.appendingPathComponent("\(tab.uuidString).jsonl") }

    public func loadState() -> AppState {
        queue.sync {
            guard let data = try? Data(contentsOf: stateURL),
                  let state = try? decoder.decode(AppState.self, from: data),
                  !state.workspaces.isEmpty else { return AppState.fresh() }
            return state
        }
    }

    public func saveState(_ state: AppState) throws {
        try queue.sync {
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
        }
    }

    public func append(_ entry: HistoryEntry, tab: UUID) throws {
        try queue.sync {
            var line = try lineEncoder.encode(entry)
            line.append(0x0A)
            let url = historyURL(tab)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let h = try FileHandle(forWritingTo: url)
            defer { try? h.close() }
            try h.seekToEnd()
            try h.write(contentsOf: line)
        }
    }

    /// Newest first. Corrupt lines (e.g. torn write on crash) are skipped.
    public func history(tab: UUID, limit: Int = 500, matching query: String? = nil) -> [HistoryEntry] {
        queue.sync {
            guard let text = try? String(contentsOf: historyURL(tab), encoding: .utf8) else { return [] }
            var out: [HistoryEntry] = []
            for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
                guard let e = try? decoder.decode(HistoryEntry.self, from: Data(line.utf8)) else { continue }
                if let q = query, !q.isEmpty, !e.command.localizedCaseInsensitiveContains(q) { continue }
                out.append(e)
                if out.count >= limit { break }
            }
            return out
        }
    }

    public func deleteHistory(tab: UUID) {
        queue.sync { try? FileManager.default.removeItem(at: historyURL(tab)) }
    }
}
