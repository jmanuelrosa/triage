# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Triage is a native macOS menu-bar app that intercepts every clicked link and routes it to the right browser (and right Chrome profile) based on a YAML rule file at `~/.config/triage/config.yaml`. The repo also contains an Astro landing site under `web/`.

## Commands

Swift app (run from repo root):

```sh
swift test                          # run the TriageCore test suite (uses swift-testing, not XCTest)
swift test --filter <TestName>      # run a single test or suite
./Scripts/build.sh                  # build Triage.app (release, native arch)
./Scripts/build.sh debug            # debug config (faster compile)
UNIVERSAL=1 ./Scripts/build.sh      # universal binary; needs full Xcode (CI uses this)
./Scripts/release.sh <version>      # bump Info.plist, commit, tag — triggers release.yml
```

After building locally, install + register so LaunchServices sees the new bundle:

```sh
cp -R Triage.app /Applications/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Triage.app
open /Applications/Triage.app
log stream --predicate 'subsystem == "com.jmrosamoncayo.triage"' --info
```

Landing site (run from `web/`, Bun is the package manager — Node 22+ required):

```sh
bun install
bun run dev       # astro dev
bun run check     # astro check (type-check)
bun run build     # prebuild generates OG images via scripts/generate-og.mjs, then astro build
```

## Architecture

Two SwiftPM targets with a hard separation:

- **`Sources/TriageCore/`** — AppKit-free pure logic. Everything that can be unit-tested lives here: `Config` (YAML parsing + validation), `Rule` / `MatchContext` / `RuleMatcher` (first-match-wins rule evaluation), `Glob` (`*`-glob, anchored, case-insensitive), `ChromeProfileResolver` (parses Chrome's `Local State` JSON to map friendly profile names → `Profile N` directory names), `BrowserLauncher` (pure argv builder for `/usr/bin/open`), `State` (`fallback-browser.json`), `CwdResolver` (protocol so `URLHandler` can be tested without `ps`). New logic almost always belongs here.
- **`Sources/triage/`** — the executable. AppKit, Apple Events, NSWorkspace, `Process.run()`. Thin wiring layer over `TriageCore`: `AppDelegate` (status bar + menus), `URLHandler` (orchestrates the routing pipeline), `ConfigWatcher` (DispatchSource file watcher), `DefaultBrowser` / `LoginItem` (LaunchServices + SMAppService), `FirstRunSetup`, `InstalledBrowsers`, `FileLog` (plain-text error log at `~/.config/triage/triage.log`).

End-to-end URL routing pipeline (all wired in `URLHandler.handle`):

```
kAEGetURL Apple Event → AppDelegate.handleURLEvent
  → URLHandler builds MatchContext (host, path, sourceBundleID/Name from senderPID, optional cwd)
  → RuleMatcher.firstMatch (rule's host/path/source_app/cwd all optional; missing = match-any)
  → Config.browsers[matched.browser] → Browser (bundle_id + optional profile name)
  → ChromeProfileResolver maps profile name → directory
  → BrowserLauncher.argv → /usr/bin/open -n -b <bundle> [--args --profile-directory=<dir>] <url>
  → Process.run()
```

Notable wiring constraints that the code already documents but are easy to break:

- The kAEGetURL handler is registered in `applicationWillFinishLaunching`, not `Did…`. On a cold-launch-from-click, the event is delivered between the two; registering in `Did` drops the first URL. See `AppDelegate.swift:20`.
- `URLHandler` short-circuits if the resolved browser bundle ID equals our own — otherwise a misconfigured fallback would route URLs back to us in an infinite loop.
- `NSMenu.autoenablesItems = false` is intentional: `refreshDynamicMenuItems()` is the single source of truth for the "Set as Default Web Browser" / "Launch at Login" items' enabled state, called on every `menuNeedsUpdate`. AppKit's auto-validation would clobber it.
- Fallback browser is captured on first launch via `FirstRunSetup.captureDefaultBrowserIfNeeded()` and stored in `~/.config/triage/fallback-browser.json`. If we were already the default at first launch, an inferred fallback is picked and the user is told.

## Tests

Tests live in `Tests/TriageCoreTests/` and use **swift-testing** (`@Test`, `#expect`) — not XCTest. The reason is that macOS Command Line Tools (the supported dev setup) doesn't ship XCTest, but Swift 6.2's bundled swift-testing works. UI-side code in `Sources/triage/` is exercised manually; only `TriageCore` has unit tests. The `swiftLanguageModes: [.v5]` in `Package.swift` is deliberate — the toolchain bump to 6.2 is just to get swift-testing; strict-concurrency migration is a separate effort.

## Conventions

- Public surface in `TriageCore` is marked `public`; everything else stays internal. Don't widen access without need.
- Adding a runtime dependency is a big deal — Yams + swift-testing is the entire dependency budget. Requires justification in the PR.
- Comments explain *why*, not *what*. `URLHandler.swift` loop-protection and `AppDelegate.swift:20` willFinishLaunching note are the model.
- Commit messages: lowercase imperative (`add ChromeProfileResolver: …`, `wire URL routing pipeline end-to-end`).

## Repo-specific guardrails

- **No silent system-state changes.** Every mutation of system state (setting Triage as default browser, enabling Launch at Login, changing the fallback) must originate from an explicit user click in the menu bar. Don't add auto-prompts or first-run nudges that mutate state.
- **No Claude references in the public repo.** This is a public repo — never commit `.claude/` paths, plan filenames, or "Claude Code" / "Generated by" / "Co-Authored-By: Claude" mentions to tracked files or commit messages. Attribution is handled at the platform level.

## CI

`.github/workflows/ci.yml` uses `dorny/paths-filter` to skip the macOS test job on docs/web-only PRs (skipped jobs still report success to branch protection). The `web-check` job builds the Astro site on Ubuntu with Node 24 + Bun. GitLeaks runs on every PR regardless of paths.
