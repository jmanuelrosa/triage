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
    let cwdResolver: CwdResolving

    init(
        configURL: URL = Config.defaultURL,
        stateURL: URL = State.defaultURL,
        chromeLocalStateURL: URL = ChromeProfileResolver.defaultLocalStateURL,
        ownBundleID: String = Bundle.main.bundleIdentifier ?? "com.jmrosamoncayo.triage",
        cwdResolver: CwdResolving = SystemCwdResolver()
    ) {
        self.configURL = configURL
        self.stateURL = stateURL
        self.chromeLocalStateURL = chromeLocalStateURL
        self.ownBundleID = ownBundleID
        self.cwdResolver = cwdResolver
    }

    func handle(url rawURL: String, senderPID: pid_t) {
        let sender = senderPID > 0
            ? NSRunningApplication(processIdentifier: senderPID)
            : nil
        let sourceBundleID = sender?.bundleIdentifier
        let sourceAppName = sender?.localizedName

        guard let parsed = URL(string: rawURL) else {
            log.error("could not parse url: \(rawURL, privacy: .public)")
            return
        }

        let config = loadConfigOrEmpty()
        let (resolvedCwd, cwdSource) = resolveCwd(
            parsedURL: parsed, senderPID: senderPID, config: config
        )

        log.info("""
        url=\(rawURL, privacy: .public)
          sender=\(sourceAppName ?? "?", privacy: .public) [\(sourceBundleID ?? "?", privacy: .public)] pid=\(senderPID, privacy: .public)
          cwd=\(resolvedCwd ?? "?", privacy: .public) cwd-source=\(cwdSource, privacy: .public)
        """)

        let chromeResolver = loadChromeResolverOrEmpty()

        let context = MatchContext(
            host: parsed.host,
            path: parsed.path.isEmpty ? "/" : parsed.path,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            cwd: resolvedCwd
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

    /// Two-step cwd resolution: try the AE sender PID first (works for
    /// terminal-launched URLs); if that fails and the URL host is recognised
    /// as loopback (built-in localhost/127.0.0.1/::1, conventional `.local`/
    /// `.localhost`/`.test` TLDs, or a user-defined `loopback_aliases` entry)
    /// with an explicit port, try the process listening on that port (works
    /// for dev-server auto-opens, where `/usr/bin/open` exits before the AE
    /// arrives). Returns the resolved cwd and a tag for logging.
    private func resolveCwd(
        parsedURL: URL,
        senderPID: pid_t,
        config: Config
    ) -> (String?, String) {
        if let cwd = cwdResolver.resolveCwd(senderPID: senderPID) {
            return (cwd, "sender")
        }
        guard let host = parsedURL.host,
              config.isLoopbackHost(host),
              let port = parsedURL.port,
              port > 0, port <= 65535
        else { return (nil, "none") }
        if let cwd = cwdResolver.resolveCwd(listeningOnPort: UInt16(port)) {
            return (cwd, "port")
        }
        return (nil, "none")
    }

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
