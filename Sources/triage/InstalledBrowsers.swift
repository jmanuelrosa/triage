import AppKit
import Foundation

struct InstalledBrowser: Equatable {
    let name: String
    let bundleID: String
}

/// Enumerates apps registered as http handlers via LaunchServices, excluding
/// Triage itself. Used by the *Set Fallback Browser* submenu and by
/// `FirstRunSetup` when the user already made Triage the system default
/// before launching it (and we therefore can't capture a previous default).
enum InstalledBrowsers {

    static func list(excluding ownBundleID: String) -> [InstalledBrowser] {
        guard let probe = URL(string: "https://example.com") else { return [] }
        let handlerURLs = NSWorkspace.shared.urlsForApplications(toOpen: probe)
        let ownLower = ownBundleID.lowercased()

        var seen: Set<String> = []
        var result: [InstalledBrowser] = []
        for appURL in handlerURLs {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier
            else { continue }
            let lowered = bundleID.lowercased()
            if lowered == ownLower || seen.contains(lowered) { continue }
            seen.insert(lowered)

            let name = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.localizedInfoDictionary?["CFBundleName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? bundleID
            result.append(InstalledBrowser(name: name, bundleID: bundleID))
        }
        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
