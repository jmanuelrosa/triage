import AppKit
import Foundation
import OSLog
import TriageCore

private let log = Logger(subsystem: "com.jmrosamoncayo.triage", category: "first-run")

/// Snapshots the system's current default http handler into
/// `fallback-browser.json` on first launch — *before* the user sets Triage as
/// the default. That captured bundle ID is the silent fallback for URLs
/// matching no rule.
///
/// If the system default is *already* Triage at first launch (the user copied
/// us to /Applications and made us default before they ever ran us), we infer
/// a fallback by enumerating other installed browsers via LaunchServices.
/// `AppDelegate` shows a one-time alert in that case so the user knows we
/// guessed.
enum FirstRunSetup {

    enum CaptureResult: Equatable {
        /// `fallback-browser.json` already existed; no work done.
        case alreadyHadState
        /// Read the system default http handler and saved its bundle ID.
        case captured(bundleID: String)
        /// Triage was already the system default; picked the first non-Triage
        /// installed browser instead. UI should surface this once.
        case inferred(bundleID: String)
        /// Nothing to capture and no other browser found. State left absent;
        /// `URLHandler` will fall back to its hardcoded Safari last-resort.
        case noBrowserFound
    }

    static func captureDefaultBrowserIfNeeded(
        stateURL: URL = State.defaultURL,
        ownBundleID: String = Bundle.main.bundleIdentifier ?? "com.jmrosamoncayo.triage"
    ) -> CaptureResult {
        if FileManager.default.fileExists(atPath: stateURL.path) {
            return .alreadyHadState
        }

        let systemDefault = resolveSystemDefaultHandler()
        let isUs = systemDefault?.caseInsensitiveCompare(ownBundleID) == .orderedSame

        let chosen: (bundleID: String, inferred: Bool)?
        if let id = systemDefault, !isUs {
            chosen = (id, false)
        } else {
            // System default is missing or is us. Pick a sibling.
            chosen = InstalledBrowsers.list(excluding: ownBundleID).first.map {
                ($0.bundleID, true)
            }
        }

        guard let pick = chosen else {
            log.error("no installed http handler found — leaving fallback-browser.json absent")
            return .noBrowserFound
        }

        let state = State(fallbackBrowserBundleID: pick.bundleID)
        do {
            try state.save(to: stateURL)
        } catch {
            log.error("could not write fallback-browser.json: \(String(describing: error), privacy: .public)")
            return .noBrowserFound
        }

        if pick.inferred {
            log.info("inferred fallback (we were already default): \(pick.bundleID, privacy: .public)")
            return .inferred(bundleID: pick.bundleID)
        } else {
            log.info("captured system default: \(pick.bundleID, privacy: .public)")
            return .captured(bundleID: pick.bundleID)
        }
    }

    private static func resolveSystemDefaultHandler() -> String? {
        guard let probe = URL(string: "https://example.com") else { return nil }
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return nil }
        return Bundle(url: appURL)?.bundleIdentifier
    }
}
