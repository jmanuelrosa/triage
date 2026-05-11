import Testing
@testable import TriageCore

@Suite("RuleMatcher")
struct RuleMatcherTests {

    // MARK: - Empty / catch-all

    @Test func emptyRules_returnsNil() {
        let context = MatchContext(host: "example.com", path: "/")
        #expect(RuleMatcher.firstMatch(rules: [], for: context) == nil)
    }

    @Test func catchAllRule_matchesAnyURL() {
        let rule = Rule(browser: "fallback")
        let context = MatchContext(host: "anywhere.com", path: "/anything")
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == rule)
    }

    // MARK: - Host matching

    @Test func exactHostMatch() {
        let rule = Rule(host: "github.com", browser: "chrome")
        let context = MatchContext(host: "github.com", path: "/")
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == rule)
    }

    @Test(arguments: ["app.acme.io", "consent.api.acme.io"])
    func wildcardSubdomainMatch(host: String) {
        let rule = Rule(host: "*.acme.io", browser: "helium")
        let context = MatchContext(host: host, path: "/")
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == rule)
    }

    @Test func wildcardSubdomainDoesNotMatchBareDomain() {
        // "*.acme.io" requires SOMETHING before .acme.io.
        let rule = Rule(host: "*.acme.io", browser: "helium")
        #expect(
            RuleMatcher.firstMatch(rules: [rule], for: MatchContext(host: "acme.io", path: "/")) == nil
        )
    }

    @Test func wildcardDoesNotMatchOutsideAnchor() {
        // "acme.io.evil.com" must not match "*.acme.io" — pattern is anchored.
        let rule = Rule(host: "*.acme.io", browser: "helium")
        #expect(
            RuleMatcher.firstMatch(rules: [rule], for: MatchContext(host: "acme.io.evil.com", path: "/")) == nil
        )
    }

    @Test func caseInsensitiveHost() {
        let rule = Rule(host: "GitHub.com", browser: "chrome")
        let context = MatchContext(host: "github.com", path: "/")
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == rule)
    }

    @Test func dotIsLiteral() {
        // The "." in "acme.io" must match a literal "." not any character.
        let rule = Rule(host: "acme.io", browser: "helium")
        #expect(
            RuleMatcher.firstMatch(rules: [rule], for: MatchContext(host: "acmeXio", path: "/")) == nil
        )
    }

    @Test func nilContextHost_failsHostRule() {
        let rule = Rule(host: "github.com", browser: "chrome")
        let context = MatchContext(host: nil, path: "/")
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == nil)
    }

    // MARK: - Path matching

    @Test func pathGlob_matchesNestedPath() {
        let rule = Rule(host: "github.com", path: "/globex/*", browser: "helium")
        let result = RuleMatcher.firstMatch(
            rules: [rule],
            for: MatchContext(host: "github.com", path: "/globex/api/pull/1569")
        )
        #expect(result == rule)
    }

    @Test func pathGlob_doesNotMatchOtherOrg() {
        let rule = Rule(host: "github.com", path: "/globex/*", browser: "helium")
        let result = RuleMatcher.firstMatch(
            rules: [rule],
            for: MatchContext(host: "github.com", path: "/3bitslost-team/pickleballontime")
        )
        #expect(result == nil)
    }

    @Test func pathGlob_doesNotMatchBareOrg() {
        // "/globex/*" requires at least an empty trailing segment ("/globex/").
        let rule = Rule(host: "github.com", path: "/globex/*", browser: "helium")
        let result = RuleMatcher.firstMatch(
            rules: [rule],
            for: MatchContext(host: "github.com", path: "/globex")
        )
        #expect(result == nil)
    }

    // MARK: - Source-app matching

    @Test func sourceApp_matchesByDisplayName() {
        let rule = Rule(sourceApp: "Slack", browser: "helium")
        let context = MatchContext(
            host: nil, path: "/",
            sourceBundleID: "com.tinyspeck.slackmacgap",
            sourceAppName: "Slack"
        )
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == rule)
    }

    @Test func sourceApp_matchesByBundleID() {
        let rule = Rule(sourceApp: "com.tinyspeck.slackmacgap", browser: "helium")
        let context = MatchContext(
            host: nil, path: "/",
            sourceBundleID: "com.tinyspeck.slackmacgap",
            sourceAppName: "Slack"
        )
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == rule)
    }

    @Test func sourceApp_caseInsensitive() {
        let rule = Rule(sourceApp: "slack", browser: "helium")
        let context = MatchContext(
            host: nil, path: "/",
            sourceBundleID: nil,
            sourceAppName: "Slack"
        )
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == rule)
    }

    @Test func sourceApp_mismatchFails() {
        let rule = Rule(sourceApp: "Slack", browser: "helium")
        let context = MatchContext(
            host: nil, path: "/",
            sourceBundleID: "net.whatsapp.WhatsApp",
            sourceAppName: "WhatsApp"
        )
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == nil)
    }

    @Test func sourceApp_requiredButContextMissing() {
        let rule = Rule(sourceApp: "Slack", browser: "helium")
        let context = MatchContext(host: "example.com", path: "/")
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == nil)
    }

    // MARK: - First-match-wins ordering

    @Test func firstMatchWins() {
        let rules = [
            Rule(host: "github.com", path: "/globex/*", browser: "helium"),
            Rule(host: "github.com", browser: "chrome_personal"),
        ]
        let context = MatchContext(host: "github.com", path: "/globex/api")
        #expect(RuleMatcher.firstMatch(rules: rules, for: context)?.browser == "helium")
    }

    @Test func secondRuleMatches_whenFirstDoesNot() {
        let rules = [
            Rule(host: "github.com", path: "/globex/*", browser: "helium"),
            Rule(host: "github.com", browser: "chrome_personal"),
        ]
        let context = MatchContext(host: "github.com", path: "/anyone-else")
        #expect(RuleMatcher.firstMatch(rules: rules, for: context)?.browser == "chrome_personal")
    }

    // MARK: - Realistic end-to-end scenarios (mirrors the plan's example YAML)

    private static let realisticRules: [Rule] = [
        Rule(host: "*.acme.io", browser: "helium"),
        Rule(host: "*.globex.com", browser: "helium"),
        Rule(host: "gitlab.com", path: "/acme/*", browser: "helium"),
        Rule(host: "github.com", path: "/globex/*", browser: "helium"),
        Rule(host: "github.com", path: "/3bitslost-team/*", browser: "chrome_3bits"),
        Rule(sourceApp: "Slack", browser: "helium"),
    ]

    @Test func realistic_acmeAppURL() {
        let result = RuleMatcher.firstMatch(
            rules: Self.realisticRules,
            for: MatchContext(host: "app.acme.io", path: "/dashboard")
        )
        #expect(result?.browser == "helium")
    }

    @Test func realistic_githubGlobexPR() {
        let result = RuleMatcher.firstMatch(
            rules: Self.realisticRules,
            for: MatchContext(host: "github.com", path: "/globex/api/pull/1569")
        )
        #expect(result?.browser == "helium")
    }

    @Test func realistic_github3bitsRepo() {
        let result = RuleMatcher.firstMatch(
            rules: Self.realisticRules,
            for: MatchContext(host: "github.com", path: "/3bitslost-team/pickleballontime")
        )
        #expect(result?.browser == "chrome_3bits")
    }

    @Test func realistic_gitlabAcmeMR() {
        let result = RuleMatcher.firstMatch(
            rules: Self.realisticRules,
            for: MatchContext(host: "gitlab.com", path: "/acme/partner-portal/SPA/-/merge_requests/56")
        )
        #expect(result?.browser == "helium")
    }

    @Test func realistic_slackSourceCatchAll() {
        let result = RuleMatcher.firstMatch(
            rules: Self.realisticRules,
            for: MatchContext(
                host: "anyrandom.com", path: "/",
                sourceBundleID: "com.tinyspeck.slackmacgap",
                sourceAppName: "Slack"
            )
        )
        #expect(result?.browser == "helium")
    }

    @Test func realistic_unmatchedURL_returnsNil() {
        let result = RuleMatcher.firstMatch(
            rules: Self.realisticRules,
            for: MatchContext(
                host: "wikipedia.org", path: "/wiki/Cat",
                sourceBundleID: "com.apple.Safari",
                sourceAppName: "Safari"
            )
        )
        #expect(result == nil)
    }
}
