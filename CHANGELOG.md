# Changelog

All notable changes to Triage are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] — 2026-05-14

### Added
- Status-bar menu item *Set as Default Web Browser* — calls `NSWorkspace.setDefaultApplication` for `http`/`https`. macOS shows its own confirmation dialog. Relabels to *Triage is the Default Web Browser* (greyed) once the role is held, refreshed on every menu open so System Settings changes show up without restart.
- Status-bar menu item *Launch at Login* — toggles `SMAppService.mainApp` registration. `.requiresApproval` and `.notFound` (app outside `/Applications`) surface an alert with a deep-link button into the relevant System Settings pane.

### Changed
- README install instructions point at the new menu items instead of *System Settings → Desktop & Dock*; the troubleshooting section now suggests checking the menu before reaching for `plutil`.

### Fixed
- Release workflow now runs on `macos-26`, which ships the Swift 6.2 toolchain `Package.swift` requires. The `v0.1.0` tag-push failed silently against `macos-14`'s Swift 5.10, leaving the release without any uploaded artifacts and the Homebrew cask URL 404ing.

## [0.1.0] — Initial public beta

> First public release. Covers the full Phase 2 + Phase 3 scope from the original plan.

### Added
- Rule-based URL routing by host glob, path glob, and source app — first-match-wins, case-insensitive.
- YAML config at `~/.config/triage/config.yaml`, parsed via Yams.
- Chrome profile resolution: human-readable profile names in YAML are mapped to directory names by reading Chrome's `Local State`.
- Auto-captured fallback browser at `~/.config/triage/fallback-browser.json` — recorded on first launch from the system's previous default.
- Already-default edge case: if Triage is the system default at first launch, falls back to the first non-Triage installed browser and surfaces a one-time menu-bar alert.
- Live config reload via a `DispatchSource` file watcher; broken YAML triggers a modal alert and writes a line to `~/.config/triage/triage.log`.
- Status-bar menu: *Reload Config*, *Open Config File*, *Set Fallback Browser →*, *Quit*.
- Startup config validation — broken YAML on disk surfaces immediately on launch instead of silently routing to the fallback.
- Append-only error log at `~/.config/triage/triage.log`.
- Universal binary (arm64 + x86_64) shipped via Homebrew Cask, DMG, and `install.sh`.
- GitHub Actions release pipeline triggered by `v*` tags.

### Security
- Triage runs as a `.accessory` app with `LSUIElement = true` — no Dock icon, no Cmd-Tab presence.
- Loop protection: if a rule or `fallback-browser.json` resolves back to Triage's own bundle ID, the URL is forwarded to Safari instead of recursing.

### Known limitations
- Builds are unsigned (no Apple Developer ID yet). Homebrew Cask + `install.sh` strip the Gatekeeper quarantine attribute automatically; DMG users must right-click → Open the first time.
- `open <url>` from Terminal — the AE sender PID is `/usr/bin/open`, which exits before we can resolve it. Such URLs route to the fallback browser.
- No auto-update mechanism (Sparkle deferred until notarization is in place).

[Unreleased]: https://github.com/jmanuelrosa/triage/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/jmanuelrosa/triage/releases/tag/v0.1.1
[0.1.0]: https://github.com/jmanuelrosa/triage/releases/tag/v0.1.0
