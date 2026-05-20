import Foundation
import Testing
@testable import TriageCore

@Suite("CwdResolver")
struct CwdResolverTests {

    // MARK: - SystemCwdResolver defensive branches

    /// Negative / zero PIDs come straight back as nil — the protocol is
    /// "best-effort, strict-fail" and a bad PID is a fail.
    @Test func systemResolver_invalidPID_returnsNil() {
        let resolver = SystemCwdResolver()
        #expect(resolver.resolveCwd(senderPID: 0) == nil)
        #expect(resolver.resolveCwd(senderPID: -1) == nil)
    }

    /// A live PID that isn't `/usr/bin/open` must return nil. The test
    /// binary itself satisfies this: it's running, but it's a test
    /// executable, not `open`.
    @Test func systemResolver_nonOpenSender_returnsNil() {
        let resolver = SystemCwdResolver()
        let selfPID = ProcessInfo.processInfo.processIdentifier
        #expect(resolver.resolveCwd(senderPID: selfPID) == nil)
    }

    /// A PID that almost certainly doesn't exist (very high number) must
    /// also fall through cleanly to nil — proc_pidpath fails and we
    /// return early.
    @Test func systemResolver_nonexistentPID_returnsNil() {
        let resolver = SystemCwdResolver()
        // pid_t max on macOS is typically 99999; pick something well above.
        #expect(resolver.resolveCwd(senderPID: 9_999_999) == nil)
    }

    // MARK: - Protocol contract via mock

    /// Wiring sanity check: a Rule with `cwd:` matches when a mock resolver
    /// returns the expected cwd; it doesn't match when the resolver returns
    /// nil. This exercises the integration point that URLHandler relies on.
    @Test func mockResolver_drivesRuleMatcher() {
        let resolved = MockCwdResolver(result: "/Users/foo/work/proj")
        let unresolved = MockCwdResolver(result: nil)

        let rule = Rule(cwd: "/Users/foo/work/*", browser: "work")

        // Simulating what URLHandler does: build a MatchContext from the
        // resolver's output, then run the matcher.
        let resolvedContext = MatchContext(
            host: nil, path: "/",
            cwd: resolved.resolveCwd(senderPID: 1234)
        )
        let unresolvedContext = MatchContext(
            host: nil, path: "/",
            cwd: unresolved.resolveCwd(senderPID: 1234)
        )

        #expect(RuleMatcher.firstMatch(rules: [rule], for: resolvedContext) == rule)
        #expect(RuleMatcher.firstMatch(rules: [rule], for: unresolvedContext) == nil)
    }
}

/// Minimal mock so URLHandler-level wiring can be exercised without
/// hitting `proc_pidinfo`. Lives next to the tests to keep production
/// surface area small.
private struct MockCwdResolver: CwdResolving {
    let result: String?
    func resolveCwd(senderPID: pid_t) -> String? { result }
}
