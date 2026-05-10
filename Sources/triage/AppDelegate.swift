import AppKit
import TriageCore
import OSLog

private let log = Logger(subsystem: "com.jmrosamoncayo.triage", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let urlHandler = URLHandler()
    private var statusItem: NSStatusItem?
    private var configWatcher: ConfigWatcher?
    private var firstRunResult: FirstRunSetup.CaptureResult = .alreadyHadState

    // Register here, NOT in applicationDidFinishLaunching: when macOS cold-launches
    // us in response to a URL click, the kAEGetURL event is delivered between
    // willFinishLaunching and didFinishLaunching. Registering in `Did` drops the
    // first URL.
    func applicationWillFinishLaunching(_ notification: Notification) {
        firstRunResult = FirstRunSetup.captureDefaultBrowserIfNeeded()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Triage launched, pid=\(getpid(), privacy: .public)")
        installStatusItem()
        startConfigWatcher()
        validateConfigAtStartup()
        notifyIfInferredFallback()
    }

    /// Surface broken YAML at launch. The watcher only fires on edits *after*
    /// launch, so without this, a user with bad YAML on disk would see URLs
    /// silently route to the fallback browser with no signal of why.
    private func validateConfigAtStartup() {
        let url = Config.defaultURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            _ = try Config.load(from: url)
        } catch {
            FileLog.error("config invalid at startup: \(error)")
            showAlert(title: "Config error", message: "\(error)")
        }
    }

    private func notifyIfInferredFallback() {
        guard case .inferred(let bundleID) = firstRunResult else { return }
        let displayName = InstalledBrowsers.list(excluding: "")
            .first { $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame }?
            .name ?? bundleID
        showAlert(
            title: "Fallback browser auto-selected",
            message: """
            Triage was already your default browser at first launch, so it picked \
            \(displayName) as the silent fallback for URLs that match no rule.

            Change it any time via the menu bar → Set Fallback Browser.
            """
        )
    }

    private func startConfigWatcher() {
        let watcher = ConfigWatcher { [weak self] result in
            self?.handleConfigReload(result)
        }
        watcher.start()
        configWatcher = watcher
    }

    private func handleConfigReload(_ result: Result<Config, Error>) {
        switch result {
        case .success(let config):
            log.info("config reloaded: \(config.browsers.count, privacy: .public) browser(s), \(config.rules.count, privacy: .public) rule(s)")
        case .failure(let error):
            // Surface YAML mistakes immediately so the user knows their edit
            // is broken instead of silently routing to the fallback browser.
            FileLog.error("config reload failed: \(error)")
            showAlert(title: "Config error", message: "\(error)")
        }
    }

    @objc func handleURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent reply: NSAppleEventDescriptor
    ) {
        guard let url = event
            .paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?
            .stringValue
        else {
            log.error("kAEGetURL had no URL")
            return
        }

        // 'spid' = keySenderPIDAttr — the PID of the originating process.
        // Resolves to the user-visible source app (Slack, Notion, …) instead
        // of ourselves, even though macOS activates us to handle the event.
        let senderPID = event
            .attributeDescriptor(forKeyword: AEKeyword(0x73706964))?
            .int32Value ?? 0

        urlHandler.handle(url: url, senderPID: senderPID)
    }

    // MARK: - Status bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(
            systemSymbolName: "arrow.triangle.branch",
            accessibilityDescription: "Triage"
        )
        item.button?.image = icon
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let reload = NSMenuItem(
            title: "Reload Config",
            action: #selector(reloadConfig),
            keyEquivalent: "r"
        )
        reload.target = self
        menu.addItem(reload)

        let open = NSMenuItem(
            title: "Open Config File",
            action: #selector(openConfigFile),
            keyEquivalent: "o"
        )
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let fallback = NSMenuItem(title: "Set Fallback Browser", action: nil, keyEquivalent: "")
        fallback.submenu = buildFallbackSubmenu()
        menu.addItem(fallback)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Triage",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    private func buildFallbackSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let ownBundleID = Bundle.main.bundleIdentifier ?? "com.jmrosamoncayo.triage"
        let browsers = InstalledBrowsers.list(excluding: ownBundleID)
        let currentFallback = (try? State.load(from: State.defaultURL))?.fallbackBrowserBundleID

        if browsers.isEmpty {
            submenu.addItem(NSMenuItem(
                title: "(no other browsers installed)",
                action: nil,
                keyEquivalent: ""
            ))
            return submenu
        }

        for browser in browsers {
            let item = NSMenuItem(
                title: browser.name,
                action: #selector(setFallback(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = browser.bundleID
            if let current = currentFallback,
               current.caseInsensitiveCompare(browser.bundleID) == .orderedSame {
                item.state = .on
            }
            submenu.addItem(item)
        }

        return submenu
    }

    // MARK: - Actions

    @objc private func reloadConfig() {
        do {
            let config = try Config.load(from: Config.defaultURL)
            showAlert(
                title: "Config valid",
                message: "\(config.browsers.count) browser(s), \(config.rules.count) rule(s)\n\n\(Config.defaultURL.path)"
            )
        } catch {
            showAlert(title: "Config error", message: "\(error)")
        }
    }

    @objc private func openConfigFile() {
        let url = Config.defaultURL
        let createdNow = !FileManager.default.fileExists(atPath: url.path)
        if createdNow {
            let directory = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let template = """
            browsers: {}
            rules: []
            """
            try? template.write(to: url, atomically: true, encoding: .utf8)
            // Watcher started during applicationDidFinishLaunching saw no file;
            // now that one exists, kick it so future edits trigger reloads.
            configWatcher?.restart()
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func setFallback(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        let state = State(fallbackBrowserBundleID: bundleID)
        do {
            try state.save(to: State.defaultURL)
            log.info("fallback browser set to \(bundleID, privacy: .public)")
            // Rebuild so the checkmark moves to the new selection.
            statusItem?.menu = buildMenu()
        } catch {
            showAlert(title: "Couldn't save fallback-browser.json", message: "\(error)")
        }
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
