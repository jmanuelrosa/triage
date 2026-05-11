# Triage — TODO

> Project was originally scaffolded under the name **openwith** through Phases 0–2.
> Renamed to **Triage** on 2026-05-08. Historical entries below preserve the
> original wording where it refers to the Phase 0 throwaway POC bundle (`openwith-poc`)
> and the directory layout that existed before the rename.

Chronological task list. Plan: `~/.claude/plans/i-would-like-to-bright-pixel.md`.
Tick items off as you finish them. Skip ahead only if the item is genuinely independent.

---

## Phase 0 — De-risk (do first)

Validate the assumptions that could kill the architecture before writing real code.

- [x] **POC: `.accessory` app as default browser** ✅ 2026-05-08 (LSUIElement finding revised 2026-05-10)
  Built `poc/openwith-poc.app`. Confirmed URLs route to it once selected as default.
  - **Correction (2026-05-10):** the original spike claimed `LSUIElement = true` excludes us from the System Settings → Default web browser picker. Re-tested with `CFBundleDocumentTypes` declared and **the picker still lists Triage**. Runtime `setActivationPolicy(.accessory)` *alone* leaves a ~half-second Dock flash on cold launch because LaunchServices reads dock-presence from the static plist before our policy call lands. Fix: ship with `LSUIElement=true` *and* keep the runtime call as defense-in-depth. Velja / Choosy / Finicky all use this combination.
  - `CFBundleDocumentTypes` declaring `public.html` as Viewer is required to be recognized as a "browser" (not just an http URL handler). Confirmed via Chrome and Helium Info.plist comparison.
  - Register `kAEGetURL` handler in `applicationWillFinishLaunching`, NOT `Did` — cold-launch URLs arrive before `Did`.

- [x] **POC: source-app detection across senders** ✅ 2026-05-08 (with caveat)
  `NSWorkspace.frontmostApplication` is **unreliable** — macOS activates us when launching us to handle a URL, so frontmost reads as ourselves. **Use Apple Event `keySenderPIDAttr` (`'spid'`) instead** — extracts the originating process PID directly from the event. Verified across Slack, WhatsApp, Notion — all return canonical bundle IDs (no helpers).
  *Edge case (Phase 2 fallback):* `open <url>` from Terminal reports `/usr/bin/open` PID, which is short-lived and gone before `NSRunningApplication(processIdentifier:)` can resolve it. Plan B: read process info via `sysctl(KERN_PROC, KERN_PROC_PID, …)` at event receipt to capture path/parent before exit, or maintain a workspace-activation history as fallback when sender PID resolves to nil.

- [x] **Spike: Helium bundle ID** ✅ 2026-05-08
  `net.imput.helium` (confirmed via `plutil` on Helium's Info.plist). URL invocation pattern still to be tested in the Chrome spike step.

- [x] **Spike: Chrome profile flag** ✅ 2026-05-08
  `open -na "Google Chrome" --args --profile-directory="Profile 4" "https://example.com"` works. Decision made to use **friendly profile names** in YAML (e.g. `"Jose Manuel [Dev]"`); Triage resolves them via Chrome's `Local State` JSON at launch time. Falls back to literal directory name if no display match.

  Available local profiles:
  - `Default` → josemanuel.rosamoncayo@gmail.com
  - `Profile 4` → Jose Manuel [Dev]
  - `Profile 5` → Donde la locura
  - `Profile 8` → 3bitslost
  - `Profile 9` → aoiTo

  *Open question (still unresolved):* No work profile in this list — needs clarification before Phase 1 YAML rules can target the work flow.

---

## Phase 1 — Scaffold ✅ 2026-05-08

- [x] SwiftPM project at project root (`Package.swift`, `Sources/triage/`, `Resources/Info.plist`, `Scripts/build.sh`)
- [x] Yams 5.4.0 pinned via `Package.resolved`
- [x] `Resources/Info.plist` with all Phase 0 gotchas baked in (no `LSUIElement`, `CFBundleDocumentTypes` for `public.html`/`public.xhtml`/`public.url`)
- [x] `main.swift` bootstraps `NSApplication` with `.accessory` policy
- [x] `AppDelegate.swift` registers `kAEGetURL` in `applicationWillFinishLaunching`, logs URL + AE sender PID (Phase 0 behavior, real project structure)
- [x] `Scripts/build.sh` runs `swift build` then assembles `.app` bundle with ad-hoc codesign
- [x] `git init -b main` + initial commit + Yams pin commit

---

## Phase 2 — Core implementation

Build inside-out: pure logic first (testable), then I/O, then UI.

- [x] `RuleMatcher.swift` ✅ 2026-05-08 — host glob + path glob + source-app (bundle ID or display name), first-match-wins, case-insensitive everywhere. Lives in new `TriageCore` library target.
- [x] `Tests/TriageCoreTests/RuleMatcherTests.swift` ✅ 2026-05-08 — 25 swift-testing cases (XCTest needs full Xcode; CLT-only setup uses swift-testing as an explicit SwiftPM dep).
- [x] `Config.swift` ✅ 2026-05-08 — Yams decode, validation (every rule must reference a declared browser), `Config.parse(yaml:)` + `Config.load(from:)`, structured `ConfigError` (Equatable). 11 tests in `ConfigTests`.
- [x] `ChromeProfileResolver.swift` ✅ 2026-05-08 — parses Chrome's `Local State` JSON; maps friendly profile names → directory names. Passthrough for unknown values (so `"Profile 4"` and `"Default"` work as escape hatches). Duplicate display names handled deterministically (first-by-directory-key). 12 tests in `ChromeProfileResolverTests`.
- [x] `State.swift` ✅ 2026-05-08 — `fallback-browser.json` Codable (snake_case fields, ISO-8601 dates), `State.load`/`save` with atomic write + parent-directory creation, `defaultURL = ~/.config/triage/fallback-browser.json`. 8 tests in `StateTests`. (File was originally named `state.json`; renamed for clarity 2026-05-09.)
- [x] `BrowserLauncher.swift` ✅ 2026-05-08 — pure argv builder for `/usr/bin/open`, with/without `--profile-directory`. 8 tests.
- [x] `URLHandler.swift` ✅ 2026-05-08 — full pipeline: kAEGetURL → MatchContext → RuleMatcher → browser resolution → BrowserLauncher → `Process.run`. Loop protection if a rule/state points back at us. Safari as ultimate fallback when fallback-browser.json is missing. Validated end-to-end with Slack → GitHub work-org URL → Helium.
- [x] `AppDelegate.swift` slimmed to AE handler bootstrap + delegation to `URLHandler`. Status bar / menu still pending (next slice).
- [x] `config.example.yaml` ✅ 2026-05-08 — committed plan example as a starting template.
- [x] AppDelegate menu (status bar item, *Reload Config*, *Open Config File*, *Set Fallback Browser →*, *Quit*) ✅ 2026-05-08
- [x] **Project rename: openwith → Triage** ✅ 2026-05-08 — bundle ID `com.jmrosamoncayo.triage`, executable `triage`, .app `Triage.app`, library `TriageCore`, paths `~/.config/triage/{config.yaml, fallback-browser.json}`. Phase 0 POC (`openwith-poc`) kept as historical artifact.
- [x] First-run state capture ✅ 2026-05-09 — `FirstRunSetup.captureDefaultBrowserIfNeeded()` runs at the start of `applicationWillFinishLaunching` (before AE handler registration). Uses `NSWorkspace.urlForApplication(toOpen:)` against an http probe URL and persists the resolved bundle ID to `fallback-browser.json` if absent. Skips if the captured handler is Triage itself (Phase 3 covers that edge case).

---

## Phase 3 — Polish

- [x] Config file watcher ✅ 2026-05-09 — `ConfigWatcher` uses `DispatchSource.makeFileSystemObjectSource(eventMask: [.write, .delete, .rename, .extend])`, reopens the FD on each event to handle atomic-save (editors that write-tmp-then-rename), and debounces by 100 ms. Calls back on the main queue. On parse failure it pops an alert; on success it just logs (silent — most edits succeed). Started in `applicationDidFinishLaunching`; restarted from `openConfigFile` after the template is written so first-run edits get picked up.
- [x] *Set fallback browser* submenu ✅ 2026-05-09 — already wired in Phase 2: `AppDelegate.setFallback(_:)` saves to `fallback-browser.json` and rebuilds the menu so the checkmark moves. URLHandler re-reads state on every URL event so there is no in-memory cache to invalidate.
- [x] Edge case: already-default at first launch ✅ 2026-05-10 — `FirstRunSetup.captureDefaultBrowserIfNeeded()` returns a `CaptureResult` (`alreadyHadState | captured | inferred | noBrowserFound`). When the system default resolves to Triage itself, falls through to `InstalledBrowsers.list(excluding:)` and picks the first sibling. `AppDelegate.notifyIfInferredFallback()` shows a one-time alert in `applicationDidFinishLaunching` for the `inferred` case (one-shot semantic comes free from `fallback-browser.json` existing afterward). Browser enumeration extracted from `AppDelegate.installedBrowsers()` into shared `InstalledBrowsers` helper.
- [x] Empty/malformed config robustness ✅ 2026-05-10 — `FileLog` writes a plain-text append-only error log to `~/.config/triage/triage.log` (timestamped, ISO-8601, ERROR-level only). Wired into `URLHandler.loadConfigOrEmpty()` (failure during URL routing) and `AppDelegate.handleConfigReload`/`validateConfigAtStartup` (broken YAML at launch and on save). Fall-through to the fallback browser was already in place since Phase 2; this slice adds the visibility piece. Startup validation pops a modal alert in addition to writing the log so the user can't miss broken YAML on launch.

---

## Phase 4 — Validation

- [ ] Run the full smoke test from the plan's *Verification* section (steps 1–10)
- [ ] Daily-drive for two weeks. Track friction in this file (add a *Field notes* section below).
- [ ] Confirm idle resource cost: `top -pid $(pgrep triage)` shows < 50MB RSS, ~0% CPU

---

## Phase 5 — Distribution *(deferred — only if Phase 4 earns its keep)*

- [ ] Decide: keep local-only, open-source on GitHub, or Homebrew cask
- [ ] If shipping: code signing, notarization, sparkle/auto-update
- [ ] README, screenshots, example configs

---

## Field notes

*(Use this section while daily-driving. Note anything weird, missing, or worth changing.)*
