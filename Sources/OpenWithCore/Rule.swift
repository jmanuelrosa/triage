import Foundation

public struct Rule: Codable, Equatable {
    public var host: String?
    public var path: String?
    public var sourceApp: String?
    public var browser: String

    public init(
        host: String? = nil,
        path: String? = nil,
        sourceApp: String? = nil,
        browser: String
    ) {
        self.host = host
        self.path = path
        self.sourceApp = sourceApp
        self.browser = browser
    }

    enum CodingKeys: String, CodingKey {
        case host
        case path
        case sourceApp = "source_app"
        case browser
    }
}

public struct MatchContext: Equatable {
    public var host: String?
    public var path: String
    public var sourceBundleID: String?
    public var sourceAppName: String?

    public init(
        host: String?,
        path: String,
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.host = host
        self.path = path
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
    }
}
