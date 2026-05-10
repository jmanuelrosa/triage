import Foundation
import Yams

public struct Config: Codable, Equatable {
    public var browsers: [String: Browser]
    public var rules: [Rule]

    public init(browsers: [String: Browser] = [:], rules: [Rule] = []) {
        self.browsers = browsers
        self.rules = rules
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
}
