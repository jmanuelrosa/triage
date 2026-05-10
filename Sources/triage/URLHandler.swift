import AppKit
import Foundation
import TriageCore
import OSLog

private let log = Logger(subsystem: "com.jmrosamoncayo.triage", category: "url-handler")

/// End-to-end URL routing pipeline:
///   kAEGetURL → MatchContext → RuleMatcher → Browser → BrowserLauncher → Process.run()
///
/// On no rule match, falls back to the bundle ID stored in `fallback-browser.json`. If
/// that's missing too, falls back to Safari (Phase 3 will replace this with
/// LSCopyApplicationURLsForURL enumeration + a one-time menu-bar prompt).
struct URLHandler {

    /// Last-resort fallback when fallback-browser.json is missing / unreadable.
    static let ultimateFallbackBundleID = "com.apple.Safari"

    let configURL: URL
    let stateURL: URL
    let chromeLocalStateURL: URL
    let ownBundleID: String

    init(
        configURL: URL = Config.defaultURL,
        stateURL: URL = State.defaultURL,
        chromeLocalStateURL: URL = ChromeProfileResolver.defaultLocalStateURL,
        ownBundleID: String = Bundle.main.bundleIdentifier ?? "com.jmrosamoncayo.triage"
    ) {
        self.configURL = configURL
        self.stateURL = stateURL
        self.chromeLocalStateURL = chromeLocalStateURL
        self.ownBundleID = ownBundleID
    }

    func handle(url rawURL: String, senderPID: pid_t) {
        let sender = senderPID > 0
            ? NSRunningApplication(processIdentifier: senderPID)
            : nil
        let sourceBundleID = sender?.bundleIdentifier
        let sourceAppName = sender?.localizedName

        log.info("""
        url=\(rawURL, privacy: .public)
          sender=\(sourceAppName ?? "?", privacy: .public) [\(sourceBundleID ?? "?", privacy: .public)] pid=\(senderPID, privacy: .public)
        """)

        guard let parsed = URL(string: rawURL) else {
            log.error("could not parse url: \(rawURL, privacy: .public)")
            return
        }

        let config = loadConfigOrEmpty()
        let chromeResolver = loadChromeResolverOrEmpty()

        let context = MatchContext(
            host: parsed.host,
            path: parsed.path.isEmpty ? "/" : parsed.path,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName
        )

        var browser = resolveBrowser(config: config, context: context)

        // Avoid an infinite loop if fallback-browser.json or a misconfigured rule points back at us.
        if browser.bundleID.caseInsensitiveCompare(ownBundleID) == .orderedSame {
            log.error("""
            resolved browser is Triage itself (\(browser.bundleID, privacy: .public)) — \
            falling back to \(Self.ultimateFallbackBundleID, privacy: .public) to avoid a loop
            """)
            browser = Browser(bundleID: Self.ultimateFallbackBundleID)
        }

        launch(browser: browser, url: rawURL, chromeResolver: chromeResolver)
    }

    // MARK: - Helpers

    private func loadConfigOrEmpty() -> Config {
        do {
            return try Config.load(from: configURL)
        } catch {
            log.error("config load failed: \(String(describing: error), privacy: .public)")
            FileLog.error("config load failed during URL routing — falling through to fallback browser: \(error)")
            return Config()
        }
    }

    private func loadChromeResolverOrEmpty() -> ChromeProfileResolver {
        do {
            return try ChromeProfileResolver.load(from: chromeLocalStateURL)
        } catch {
            // Quietly fall back; Chrome may not be installed at all.
            return .empty
        }
    }

    private func resolveBrowser(config: Config, context: MatchContext) -> Browser {
        if let matched = RuleMatcher.firstMatch(rules: config.rules, for: context) {
            if let browser = config.browsers[matched.browser] {
                log.info("matched rule → browser '\(matched.browser, privacy: .public)'")
                return browser
            }
            log.error("""
            rule matched but browser '\(matched.browser, privacy: .public)' not declared \
            in config — falling back
            """)
        } else {
            log.info("no rule matched, using fallback")
        }

        let fallbackID: String
        if let state = try? State.load(from: stateURL) {
            fallbackID = state.fallbackBrowserBundleID
        } else {
            log.error("fallback-browser.json missing/unreadable — using ultimate fallback Safari")
            fallbackID = Self.ultimateFallbackBundleID
        }
        return Browser(bundleID: fallbackID)
    }

    private func launch(browser: Browser, url: String, chromeResolver: ChromeProfileResolver) {
        let argv = BrowserLauncher.argv(for: browser, url: url, profileResolver: chromeResolver)
        log.info("launching: \(argv.joined(separator: " "), privacy: .public)")

        let executable = URL(fileURLWithPath: argv.first ?? BrowserLauncher.openTool)
        let arguments = Array(argv.dropFirst())
        do {
            _ = try Process.run(executable, arguments: arguments)
        } catch {
            log.error("Process.run failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
