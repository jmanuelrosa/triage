import Foundation

public struct Rule: Codable, Equatable {
    public var host: String?
    public var path: String?
    public var sourceApp: String?
    public var cwd: String?
    public var browser: String

    public init(
        host: String? = nil,
        path: String? = nil,
        sourceApp: String? = nil,
        cwd: String? = nil,
        browser: String
    ) {
        self.host = host
        self.path = path
        self.sourceApp = sourceApp
        self.cwd = cwd
        self.browser = browser
    }

    enum CodingKeys: String, CodingKey {
        case host
        case path
        case sourceApp = "source_app"
        case cwd
        case browser
    }
}

public struct MatchContext: Equatable {
    public var host: String?
    public var path: String
    public var sourceBundleID: String?
    public var sourceAppName: String?
    /// Resolved current working directory of the process that invoked the URL,
    /// when known. Only populated for terminal-launched URLs (sender resolves
    /// to `/usr/bin/open`); `nil` otherwise. Rules with `cwd:` only match when
    /// this is set, by design — see RuleMatcher.
    public var cwd: String?

    public init(
        host: String?,
        path: String,
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil,
        cwd: String? = nil
    ) {
        self.host = host
        self.path = path
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.cwd = cwd
    }
}
