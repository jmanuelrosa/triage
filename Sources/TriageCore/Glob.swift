import Foundation

enum Glob {
    /// Match a shell-style glob pattern against the input, case-insensitively,
    /// anchored at both ends. Only `*` is special; all regex metacharacters are
    /// escaped so a literal `.` in the pattern matches a literal `.` in the input.
    static func match(_ pattern: String, against input: String) -> Bool {
        var regex = "^"
        for char in pattern {
            switch char {
            case "*":
                regex += ".*"
            case ".", "+", "?", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\":
                regex.append("\\")
                regex.append(char)
            default:
                regex.append(char)
            }
        }
        regex += "$"
        return input.range(of: regex, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Match a file-path glob pattern against an input path.
    ///
    /// Performs tilde expansion on both sides, then resolves symlinks via
    /// `NSString.resolvingSymlinksInPath` so a rule like `cwd: "~/Code/*"`
    /// matches even when the process's cwd is under the symlink's target
    /// (e.g. `~/Code` symlinked to `/Volumes/External/code`). For the
    /// pattern, only the literal prefix up to the first `*` is resolved;
    /// the wildcard portion is preserved verbatim. Trailing slashes are
    /// normalized away on both sides.
    ///
    /// `resolvingSymlinksInPath` is best-effort: it walks the path and
    /// resolves what it can, leaving unresolved suffixes verbatim. macOS
    /// also un-prefixes `/private` (so `/private/tmp/foo` ↔ `/tmp/foo`).
    /// This means both sides normalize consistently even when the input
    /// path doesn't exist on disk yet (e.g. a freshly-built tmp dir).
    static func matchPath(_ pattern: String, against input: String) -> Bool {
        let normalizedPattern = normalizePathPattern(pattern)
        let normalizedInput = normalizePath(input)
        return match(normalizedPattern, against: normalizedInput)
    }

    private static func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return stripTrailingSlash((expanded as NSString).resolvingSymlinksInPath)
    }

    private static func normalizePathPattern(_ pattern: String) -> String {
        let expanded = (pattern as NSString).expandingTildeInPath
        guard let starRange = expanded.range(of: "*") else {
            return normalizePath(expanded)
        }
        let beforeStar = expanded[..<starRange.lowerBound]
        guard let lastSlash = beforeStar.lastIndex(of: "/") else {
            // Pattern starts with `*` — no literal prefix to resolve.
            return stripTrailingSlash(expanded)
        }
        let prefix = String(expanded[..<lastSlash])
        let suffix = String(expanded[lastSlash...])
        let resolvedPrefix = (prefix as NSString).resolvingSymlinksInPath
        return stripTrailingSlash(resolvedPrefix) + suffix
    }

    private static func stripTrailingSlash(_ path: String) -> String {
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }
}
