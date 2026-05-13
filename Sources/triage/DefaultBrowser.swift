import AppKit
import Foundation

/// Reads and writes Triage's role as the macOS default web browser via
/// `NSWorkspace`. Matches the style of `FirstRunSetup`, which already uses
/// `NSWorkspace.shared.urlForApplication(toOpen:)` to inspect the system
/// default — we extend that to cover both `http` and `https` and to mutate
/// the setting, never silently: `setDefaultApplication` triggers macOS's own
/// confirmation dialog ("Do you want to use 'Triage' as your default web
/// browser?") which the user must accept.
enum DefaultBrowser {

    /// True when both `http` and `https` resolve to Triage's bundle.
    static func isCurrentDefault(
        ownBundleID: String = Bundle.main.bundleIdentifier ?? "com.jmrosamoncayo.triage"
    ) -> Bool {
        currentHandler(forScheme: "http").map {
            $0.caseInsensitiveCompare(ownBundleID) == .orderedSame
        } ?? false
    }

    /// Asks macOS to set Triage as the default for both `http` and `https`.
    /// macOS surfaces its own confirmation dialog; the completion handler
    /// reports the user's choice (or any system error). Silent no-op when the
    /// user declines.
    static func makeDefault(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let appURL = ownAppURL() else {
            completion(.failure(DefaultBrowserError.bundleNotFound))
            return
        }

        let workspace = NSWorkspace.shared
        workspace.setDefaultApplication(
            at: appURL,
            toOpenURLsWithScheme: "http"
        ) { httpError in
            if let httpError {
                DispatchQueue.main.async { completion(.failure(httpError)) }
                return
            }
            workspace.setDefaultApplication(
                at: appURL,
                toOpenURLsWithScheme: "https"
            ) { httpsError in
                DispatchQueue.main.async {
                    if let httpsError {
                        completion(.failure(httpsError))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }

    private static func currentHandler(forScheme scheme: String) -> String? {
        guard let probe = URL(string: "\(scheme)://example.com") else { return nil }
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return nil }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    private static func ownAppURL() -> URL? {
        // Bundle.main.bundleURL points at the .app wrapper when launched as a
        // bundled GUI app (the only supported configuration for Triage).
        let url = Bundle.main.bundleURL
        return url.pathExtension == "app" ? url : nil
    }
}

enum DefaultBrowserError: LocalizedError {
    case bundleNotFound

    var errorDescription: String? {
        switch self {
        case .bundleNotFound:
            return "Triage isn't running from a .app bundle, so macOS can't register it as a handler."
        }
    }
}
