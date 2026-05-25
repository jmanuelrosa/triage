import Foundation
import Yams

public struct Config: Codable, Equatable {
    public var browsers: [String: Browser]
    public var rules: [Rule]
    /// Hostnames the user wants treated as loopback for cwd-port resolution,
    /// in addition to the built-in exact matches (`localhost`, `127.0.0.1`,
    /// `::1`) and conventional suffixes (`.local`, `.localhost`, `.test`).
    /// Useful for bare names in `/etc/hosts` like `my-test-app` or
    /// company-internal dev hostnames that don't end in a recognized suffix.
    public var loopbackAliases: [String]

    public init(
        browsers: [String: Browser] = [:],
        rules: [Rule] = [],
        loopbackAliases: [String] = []
    ) {
        self.browsers = browsers
        self.rules = rules
        self.loopbackAliases = loopbackAliases
    }

    enum CodingKeys: String, CodingKey {
        case browsers
        case rules
        case loopbackAliases = "loopback_aliases"
    }

    /// Custom decoder so existing configs that pre-date `loopback_aliases`
    /// keep parsing — a missing key decodes as `[]` rather than throwing.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.browsers = try container.decode([String: Browser].self, forKey: .browsers)
        self.rules = try container.decode([Rule].self, forKey: .rules)
        self.loopbackAliases = try container.decodeIfPresent(
            [String].self, forKey: .loopbackAliases
        ) ?? []
    }
}

public struct Browser: Codable, Equatable {
    public var bundleID: String
    public var profile: String?

    public init(bundleID: String, profile: String? = nil) {
        self.bundleID = bundleID
        self.profile = profile
    }

    enum CodingKeys: String, CodingKey {
        case bundleID = "bundle_id"
        case profile
    }
}

public enum ConfigError: Error, Equatable, CustomStringConvertible {
    case parseError(String)
    case unknownBrowserReference(ruleIndex: Int, browserName: String)

    public var description: String {
        switch self {
        case .parseError(let message):
            return "config parse error: \(message)"
        case .unknownBrowserReference(let index, let name):
            return "rule #\(index) references unknown browser '\(name)'"
        }
    }
}

public extension Config {
    /// Parse a YAML string into a validated Config.
    static func parse(yaml: String) throws -> Config {
        let config: Config
        do {
            config = try YAMLDecoder().decode(Config.self, from: yaml)
        } catch {
            throw ConfigError.parseError(String(describing: error))
        }
        try config.validate()
        return config
    }

    /// Load and parse a YAML config from disk.
    static func load(from url: URL) throws -> Config {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ConfigError.parseError("could not read \(url.path): \(error.localizedDescription)")
        }
        guard let yaml = String(data: data, encoding: .utf8) else {
            throw ConfigError.parseError("\(url.path) is not valid UTF-8")
        }
        return try parse(yaml: yaml)
    }

    /// Verify every rule references a declared browser.
    func validate() throws {
        for (index, rule) in rules.enumerated() where browsers[rule.browser] == nil {
            throw ConfigError.unknownBrowserReference(
                ruleIndex: index,
                browserName: rule.browser
            )
        }
    }

    /// `~/.config/triage/config.yaml`.
    static var defaultURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/triage/config.yaml")
    }

    /// Built-in exact-match hostnames recognised as loopback. Always honoured
    /// regardless of `loopback_aliases`.
    static let builtinLoopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1"]

    /// Conventional dev-server TLDs. `.local` (mDNS / Bonjour), `.localhost`
    /// (RFC 6761 reserved), and `.test` (Laravel Valet / Herd / RFC 6761).
    /// Anything ending in one of these is treated as loopback.
    static let builtinLoopbackSuffixes: [String] = [".local", ".localhost", ".test"]

    /// Whether `host` should be treated as "this machine" for the port-listener
    /// cwd fallback. Checks built-in exact matches, built-in TLD suffixes, and
    /// finally the user's `loopback_aliases`. Comparison is case-insensitive.
    func isLoopbackHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        if Config.builtinLoopbackHosts.contains(normalized) { return true }
        if Config.builtinLoopbackSuffixes.contains(where: { normalized.hasSuffix($0) }) {
            return true
        }
        return loopbackAliases.contains { $0.lowercased() == normalized }
    }
}
