import Foundation
import AppKit
import os

/// A small log file for support: ~/Library/Logs/BetterTerminal/app.log (rotated at 1 MB), plus crash notes.
/// Nothing is sent anywhere. Terminal text and commands are never logged.
enum Diagnostics {
    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/BetterTerminal", isDirectory: true)
    static let logURL = directory.appendingPathComponent("app.log")
    private static let logger = Logger(subsystem: "com.better.terminal", category: "app")
    private static let queue = DispatchQueue(label: "better-terminal.log")
    private static var crashFD: Int32 = -1

    static func log(_ message: String) {
        logger.log("\(message, privacy: .public)")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        queue.async {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let size = (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size]) as? Int, size > 1_000_000 {
                let old = directory.appendingPathComponent("app.log.1")
                try? FileManager.default.removeItem(at: old)
                try? FileManager.default.moveItem(at: logURL, to: old)
            }
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            if let h = try? FileHandle(forWritingTo: logURL) {
                _ = try? h.seekToEnd()
                try? h.write(contentsOf: Data(line.utf8))
                try? h.close()
            }
        }
    }

    /// Records launches, uncaught exceptions and fatal signals.
    static func install() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        log("launch Better Terminal \(version) (\(build)), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

        NSSetUncaughtExceptionHandler { exception in
            Diagnostics.log("uncaught exception \(exception.name.rawValue): \(exception.reason ?? "")\n" +
                            exception.callStackSymbols.prefix(25).joined(separator: "\n"))
        }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        crashFD = open(directory.appendingPathComponent("crash.log").path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        for sig in [SIGSEGV, SIGABRT, SIGILL, SIGBUS, SIGFPE, SIGTRAP] {
            signal(sig) { s in   // swiftlint:disable:this identifier_name
                // Only async-signal-safe calls here: write a fixed note, then let the default handler crash.
                let note = "fatal signal\n"
                note.withCString { _ = write(Diagnostics.crashFD, $0, strlen($0)) }
                signal(s, SIG_DFL)
                raise(s)
            }
        }
    }

    static func revealLogs() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }
}
