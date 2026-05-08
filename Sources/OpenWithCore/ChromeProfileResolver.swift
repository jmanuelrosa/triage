import Foundation

/// Maps human-readable Chrome profile names ("Jose Manuel [Dev]") to their
/// on-disk directory names ("Profile 4"), which is what Chrome's
/// `--profile-directory` flag actually accepts.
///
/// Source of truth is `~/Library/Application Support/Google/Chrome/Local State`,
/// specifically `profile.info_cache.<dir>.name`.
public struct ChromeProfileResolver: Equatable {
    /// Display name → directory name.
    public let nameToDirectory: [String: String]

    /// Display names that appeared on more than one directory. First-by-directory
    /// wins; the rest land here so a caller can log a warning.
    public let duplicates: [String]

    public init(nameToDirectory: [String: String] = [:], duplicates: [String] = []) {
        self.nameToDirectory = nameToDirectory
        self.duplicates = duplicates
    }

    public static let empty = ChromeProfileResolver()

    /// Resolve a YAML `profile:` value to a `--profile-directory` argument.
    /// Lookup precedence: exact display name → literal passthrough.
    /// The passthrough lets users specify `"Profile 4"` or `"Default"` directly.
    public func directoryName(for input: String) -> String {
        nameToDirectory[input] ?? input
    }
}

public enum ChromeProfileError: Error, Equatable, CustomStringConvertible {
    case parseError(String)

    public var description: String {
        switch self {
        case .parseError(let message):
            return "Chrome Local State parse error: \(message)"
        }
    }
}

public extension ChromeProfileResolver {
    /// Parse Chrome's Local State JSON.
    static func parse(localStateJSON: String) throws -> ChromeProfileResolver {
        let raw: LocalStateModel
        do {
            raw = try JSONDecoder().decode(
                LocalStateModel.self,
                from: Data(localStateJSON.utf8)
            )
        } catch {
            throw ChromeProfileError.parseError(String(describing: error))
        }

        let cache = raw.profile?.infoCache ?? [:]
        // Sort by directory key for deterministic duplicate handling.
        let sorted = cache.sorted { $0.key < $1.key }

        var nameToDirectory: [String: String] = [:]
        var duplicates = Set<String>()
        for (directory, info) in sorted {
            if nameToDirectory[info.name] != nil {
                duplicates.insert(info.name)
                continue
            }
            nameToDirectory[info.name] = directory
        }

        return ChromeProfileResolver(
            nameToDirectory: nameToDirectory,
            duplicates: duplicates.sorted()
        )
    }

    /// Read and parse Chrome's Local State JSON from disk.
    static func load(from url: URL) throws -> ChromeProfileResolver {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ChromeProfileError.parseError(
                "could not read \(url.path): \(error.localizedDescription)"
            )
        }
        guard let json = String(data: data, encoding: .utf8) else {
            throw ChromeProfileError.parseError("\(url.path) is not valid UTF-8")
        }
        return try parse(localStateJSON: json)
    }

    /// `~/Library/Application Support/Google/Chrome/Local State` for the current user.
    static var defaultLocalStateURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Google/Chrome/Local State")
    }
}

private struct LocalStateModel: Decodable {
    let profile: ProfileSection?

    struct ProfileSection: Decodable {
        let infoCache: [String: ProfileInfo]

        enum CodingKeys: String, CodingKey {
            case infoCache = "info_cache"
        }
    }

    struct ProfileInfo: Decodable {
        let name: String
    }
}
