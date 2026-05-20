import Foundation
#if canImport(Darwin)
import Darwin
#endif

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
    /// `realpath(3)` so a rule like `cwd: "~/Code/*"` matches even when the
    /// process's cwd is under the symlink's target (e.g. `~/Code` symlinked
    /// to `/Volumes/External/code`). For the pattern, only the literal prefix
    /// up to the first `*` is realpath'd — the wildcard portion is preserved
    /// verbatim. Trailing slashes are normalized away on both sides.
    ///
    /// Broken symlinks or non-existent prefixes fall back to the literal
    /// expanded path; the rule then almost certainly won't match (documented
    /// gotcha).
    static func matchPath(_ pattern: String, against input: String) -> Bool {
        let normalizedPattern = normalizePathPattern(pattern)
        let normalizedInput = normalizePath(input)
        return match(normalizedPattern, against: normalizedInput)
    }

    private static func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return stripTrailingSlash(realpath(expanded) ?? expanded)
    }

    private static func normalizePathPattern(_ pattern: String) -> String {
        let expanded = (pattern as NSString).expandingTildeInPath
        guard let starRange = expanded.range(of: "*") else {
            return normalizePath(expanded)
        }
        let beforeStar = expanded[..<starRange.lowerBound]
        guard let lastSlash = beforeStar.lastIndex(of: "/") else {
            // Pattern starts with `*` — no literal prefix to realpath.
            return stripTrailingSlash(expanded)
        }
        let prefix = String(expanded[..<lastSlash])
        let suffix = String(expanded[lastSlash...])
        let resolvedPrefix = realpath(prefix) ?? prefix
        return stripTrailingSlash(resolvedPrefix) + suffix
    }

    private static func realpath(_ path: String) -> String? {
        guard !path.isEmpty else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard Darwin.realpath(path, &buffer) != nil else { return nil }
        return String(cString: buffer)
    }

    private static func stripTrailingSlash(_ path: String) -> String {
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }
}
