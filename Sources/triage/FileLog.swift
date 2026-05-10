import Foundation
import TriageCore

/// Append-only error log at `~/.config/triage/triage.log`. Complements OSLog
/// (which is fine for streaming via Console.app) by giving the user a plain
/// text file they can `cat` or `tail -f` when something's misbehaving.
///
/// Only error-level events go here — info/debug noise stays in the unified log.
enum FileLog {

    static let url: URL = Config.defaultURL
        .deletingLastPathComponent()
        .appendingPathComponent("triage.log")

    private static let queue = DispatchQueue(label: "com.jmrosamoncayo.triage.file-log")

    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func error(_ message: String) {
        let line = "[\(timestampFormatter.string(from: Date()))] ERROR \(message)\n"
        queue.async { write(line) }
    }

    private static func write(_ line: String) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        } catch {
            // Logging must never crash the app — silently drop on disk error.
        }
    }
}
