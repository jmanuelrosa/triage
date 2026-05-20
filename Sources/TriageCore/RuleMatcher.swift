import Foundation

public enum RuleMatcher {
    /// Returns the first rule that matches the context, or nil if none match.
    /// Order in `rules` is significant: first match wins.
    public static func firstMatch(rules: [Rule], for context: MatchContext) -> Rule? {
        rules.first { $0.matches(context) }
    }
}

public extension Rule {
    func matches(_ context: MatchContext) -> Bool {
        if let host = host {
            guard let inputHost = context.host else { return false }
            guard Glob.match(host, against: inputHost) else { return false }
        }
        if let path = path {
            guard Glob.match(path, against: context.path) else { return false }
        }
        if let sourceApp = sourceApp {
            let bundleHit = context.sourceBundleID
                .map { $0.caseInsensitiveCompare(sourceApp) == .orderedSame } ?? false
            let nameHit = context.sourceAppName
                .map { $0.caseInsensitiveCompare(sourceApp) == .orderedSame } ?? false
            guard bundleHit || nameHit else { return false }
        }
        if let cwd = cwd {
            // Strict: a rule with `cwd:` only matches when the context carries
            // a resolved cwd (i.e. the URL was terminal-launched and the
            // resolver succeeded). Unknown cwd → no match → fall through.
            guard let contextCwd = context.cwd else { return false }
            guard Glob.matchPath(cwd, against: contextCwd) else { return false }
        }
        return true
    }
}
