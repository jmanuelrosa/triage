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
}
