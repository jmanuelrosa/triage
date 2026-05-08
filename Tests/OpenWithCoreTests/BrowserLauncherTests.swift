import Testing
@testable import OpenWithCore

@Suite("BrowserLauncher")
struct BrowserLauncherTests {

    private static let resolver = ChromeProfileResolver(
        nameToDirectory: [
            "Jose Manuel": "Default",
            "Jose Manuel [Dev]": "Profile 4",
            "3bitslost": "Profile 8"
        ]
    )

    // MARK: - Without profile

    @Test func argv_noProfile() {
        let helium = Browser(bundleID: "net.imput.helium")
        let args = BrowserLauncher.argv(for: helium, url: "https://example.com")
        #expect(args == [
            "/usr/bin/open",
            "-n",
            "-b",
            "net.imput.helium",
            "https://example.com"
        ])
    }

    @Test func argv_noProfile_doesNotIncludeArgsSeparator() {
        let helium = Browser(bundleID: "net.imput.helium")
        let args = BrowserLauncher.argv(for: helium, url: "https://example.com")
        #expect(!args.contains("--args"))
    }

    @Test func argv_emptyProfileString_treatedAsNoProfile() {
        let browser = Browser(bundleID: "com.google.Chrome", profile: "")
        let args = BrowserLauncher.argv(for: browser, url: "https://example.com")
        #expect(!args.contains("--args"))
    }

    // MARK: - With profile (Chromium)

    @Test func argv_withProfile_resolvesDisplayName() {
        let chromeDev = Browser(bundleID: "com.google.Chrome", profile: "Jose Manuel [Dev]")
        let args = BrowserLauncher.argv(
            for: chromeDev,
            url: "https://app.acme.io/dashboard",
            profileResolver: Self.resolver
        )
        #expect(args == [
            "/usr/bin/open",
            "-n",
            "-b",
            "com.google.Chrome",
            "--args",
            "--profile-directory=Profile 4",
            "https://app.acme.io/dashboard"
        ])
    }

    @Test func argv_withProfile_passthroughForUnknownName() {
        // User wrote a literal directory name; resolver passes it through.
        let chrome = Browser(bundleID: "com.google.Chrome", profile: "Profile 99")
        let args = BrowserLauncher.argv(
            for: chrome,
            url: "https://example.com",
            profileResolver: Self.resolver
        )
        #expect(args.contains("--profile-directory=Profile 99"))
    }

    @Test func argv_withProfile_passthroughForDefault() {
        // "Default" is a valid Chrome directory name.
        let chrome = Browser(bundleID: "com.google.Chrome", profile: "Default")
        let args = BrowserLauncher.argv(
            for: chrome,
            url: "https://example.com",
            profileResolver: Self.resolver
        )
        #expect(args.contains("--profile-directory=Default"))
    }

    @Test func argv_withProfile_emptyResolver_fallsBackToLiteral() {
        // No resolver loaded (e.g. Chrome never installed) — pass through whatever
        // the YAML says. Chrome will still open in that directory if it exists.
        let chrome = Browser(bundleID: "com.google.Chrome", profile: "Profile 4")
        let args = BrowserLauncher.argv(
            for: chrome,
            url: "https://example.com"
        )
        #expect(args.contains("--profile-directory=Profile 4"))
    }

    // MARK: - URL handling

    @Test func argv_URLAlwaysComesLast() {
        let chrome = Browser(bundleID: "com.google.Chrome", profile: "Default")
        let args = BrowserLauncher.argv(
            for: chrome,
            url: "https://example.com",
            profileResolver: Self.resolver
        )
        #expect(args.last == "https://example.com")
    }

    @Test func argv_URLWithSpecialCharacters_passedAsLiteralArg() {
        // Process passes argv literally — no shell quoting concerns.
        let helium = Browser(bundleID: "net.imput.helium")
        let url = "https://example.com/path?q=hello world&x=\"quoted\""
        let args = BrowserLauncher.argv(for: helium, url: url)
        #expect(args.last == url)
    }
}
