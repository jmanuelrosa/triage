import Foundation

/// Builds the `/usr/bin/open` argv used to launch a URL in a specific browser
/// (and, for Chromium-family browsers, a specific profile).
///
/// The actual `Process.run()` invocation lives in the executable target — this
/// type is intentionally pure so the argv shape is unit-testable.
public enum BrowserLauncher {

    public static let openTool = "/usr/bin/open"

    /// Build argv for `Process` to launch `url` in `browser`.
    ///
    /// Without a profile:
    ///     /usr/bin/open -n -b <bundle_id> <url>
    ///
    /// With a profile (Chromium `--profile-directory` flag):
    ///     /usr/bin/open -n -b <bundle_id> --args --profile-directory=<dir> <url>
    ///
    /// `--args` switches `open` from "open this URL via LaunchServices" to
    /// "pass these as argv to the launched process," which is what Chrome
    /// needs in order to honor `--profile-directory`. The URL becomes a
    /// positional CLI arg that Chrome opens in the chosen profile.
    public static func argv(
        for browser: Browser,
        url: String,
        profileResolver: ChromeProfileResolver = .empty
    ) -> [String] {
        var args = [openTool, "-n", "-b", browser.bundleID]
        if let profile = browser.profile, !profile.isEmpty {
            let directory = profileResolver.directoryName(for: profile)
            args.append("--args")
            args.append("--profile-directory=\(directory)")
        }
        args.append(url)
        return args
    }
}
