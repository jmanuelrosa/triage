import Foundation

/// Persistent app state, kept in `~/.config/openwith/state.json`.
///
/// Currently holds the bundle ID of the system's default browser captured at
/// openwith's first launch — used as the silent fallback for URLs that match
/// no rule. The user can change it later via the menu bar.
public struct State: Codable, Equatable {
    public var fallbackBrowserBundleID: String
    public var capturedAt: Date

    public init(fallbackBrowserBundleID: String, capturedAt: Date = Date()) {
        self.fallbackBrowserBundleID = fallbackBrowserBundleID
        self.capturedAt = capturedAt
    }

    enum CodingKeys: String, CodingKey {
        case fallbackBrowserBundleID = "fallback_browser_bundle_id"
        case capturedAt = "captured_at"
    }
}

public enum StateError: Error, Equatable, CustomStringConvertible {
    case ioError(String)
    case parseError(String)

    public var description: String {
        switch self {
        case .ioError(let message):
            return "state I/O error: \(message)"
        case .parseError(let message):
            return "state parse error: \(message)"
        }
    }
}

public extension State {
    static func load(from url: URL) throws -> State {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw StateError.ioError("could not read \(url.path): \(error.localizedDescription)")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(State.self, from: data)
        } catch {
            throw StateError.parseError(String(describing: error))
        }
    }

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data: Data
        do {
            data = try encoder.encode(self)
        } catch {
            throw StateError.parseError(String(describing: error))
        }
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw StateError.ioError(
                "could not create \(directory.path): \(error.localizedDescription)"
            )
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw StateError.ioError("could not write \(url.path): \(error.localizedDescription)")
        }
    }

    /// `~/.config/openwith/state.json`.
    static var defaultURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/openwith/state.json")
    }
}
