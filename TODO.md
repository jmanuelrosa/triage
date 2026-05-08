# openwith — TODO

Chronological task list. Plan: `~/.claude/plans/i-would-like-to-bright-pixel.md`.
Tick items off as you finish them. Skip ahead only if the item is genuinely independent.

---

## Phase 0 — De-risk (do first)

Validate the assumptions that could kill the architecture before writing real code.

- [x] **POC: `.accessory` app as default browser** ✅ 2026-05-08
  Built `poc/openwith-poc.app`. Confirmed URLs route to it once selected as default. Two non-obvious gotchas surfaced:
  - `LSUIElement = true` in Info.plist excludes the app from System Settings → Default web browser picker. Use runtime `setActivationPolicy(.accessory)` instead.
  - `CFBundleDocumentTypes` declaring `public.html` as Viewer is required to be recognized as a "browser" (not just an http URL handler). Confirmed via Chrome and Helium Info.plist comparison.
  - Register `kAEGetURL` handler in `applicationWillFinishLaunching`, NOT `Did` — cold-launch URLs arrive before `Did`.

- [x] **POC: source-app detection across senders** ✅ 2026-05-08 (with caveat)
  `NSWorkspace.frontmostApplication` is **unreliable** — macOS activates us when launching us to handle a URL, so frontmost reads as ourselves. **Use Apple Event `keySenderPIDAttr` (`'spid'`) instead** — extracts the originating process PID directly from the event. Verified across Slack, WhatsApp, Notion — all return canonical bundle IDs (no helpers).
  *Edge case (Phase 2 fallback):* `open <url>` from Terminal reports `/usr/bin/open` PID, which is short-lived and gone before `NSRunningApplication(processIdentifier:)` can resolve it. Plan B: read process info via `sysctl(KERN_PROC, KERN_PROC_PID, …)` at event receipt to capture path/parent before exit, or maintain a workspace-activation history as fallback when sender PID resolves to nil.

- [x] **Spike: Helium bundle ID** ✅ 2026-05-08
  `net.imput.helium` (confirmed via `plutil` on Helium's Info.plist). URL invocation pattern still to be tested in the Chrome spike step.

- [x] **Spike: Chrome profile flag** ✅ 2026-05-08
  `open -na "Google Chrome" --args --profile-directory="Profile 4" "https://example.com"` works. Decision made to use **friendly profile names** in YAML (e.g. `"Jose Manuel [Dev]"`); openwith resolves them via Chrome's `Local State` JSON at launch time. Falls back to literal directory name if no display match.

  Available local profiles:
  - `Default` → josemanuel.rosamoncayo@gmail.com
  - `Profile 4` → Jose Manuel [Dev]
  - `Profile 5` → Donde la locura
  - `Profile 8` → 3bitslost
  - `Profile 9` → aoiTo

  *Open question (still unresolved):* No Didomi work profile in this list — needs clarification before Phase 1 YAML rules can target the work flow.

---

## Phase 1 — Scaffold

Only start once Phase 0 passes.

- [ ] Create SwiftPM project at `/Users/jmanuelrosa/Developer/personal/openwith/`
  Files: `Package.swift`, `Sources/openwith/`, `Resources/Info.plist`, `Tests/`.
- [ ] Add Yams dependency to `Package.swift`
- [ ] Write `Resources/Info.plist`: `CFBundleURLTypes` for `http`/`https`, app metadata
- [ ] `Sources/openwith/main.swift`: bootstrap `NSApplication`, set `.accessory` policy, install AppDelegate
- [ ] `git init` + initial commit (project skeleton)

---

## Phase 2 — Core implementation

Build inside-out: pure logic first (testable), then I/O, then UI.

- [ ] `RuleMatcher.swift` — host glob + optional source_app match, first-match-wins. **Pure function, no macOS APIs.**
- [ ] `Tests/RuleMatcherTests.swift` — table-driven tests covering glob edge cases, source-app match, no-match
- [ ] `Config.swift` — YAML decode via Yams, validation, helpful error messages on malformed config
- [ ] `State.swift` — `state.json` read/write, first-run capture of `LSCopyDefaultHandlerForURLScheme("http")`
- [ ] `BrowserLauncher.swift` — `open -na <bundle_id> --args [--profile-directory=<profile>] <url>` via `Process`
- [ ] `URLHandler.swift` — register `kAEGetURL` handler, capture source app, resolve via RuleMatcher, launch via BrowserLauncher
- [ ] `AppDelegate.swift` — status-bar item, menu: *Reload config*, *Open config file*, *Set fallback browser →* (submenu of installed browsers), *Quit*

---

## Phase 3 — Polish

- [ ] Config file watcher (`DispatchSource.makeFileSystemObjectSource`) for live reload on save
- [ ] *Set fallback browser* submenu writes to `state.json` and updates in-memory state
- [ ] Edge case: `state.json` missing on first launch *because user set us as default before launching us* → enumerate installed browsers via `LSCopyApplicationURLsForURL`, pick first non-`openwith`, surface a one-time menu-bar notice
- [ ] Empty/malformed config → log to `~/.config/openwith/openwith.log`, fall back to direct fallback-browser launch (don't crash, don't drop URLs on the floor)

---

## Phase 4 — Validation

- [ ] Run the full smoke test from the plan's *Verification* section (steps 1–10)
- [ ] Daily-drive for two weeks. Track friction in this file (add a *Field notes* section below).
- [ ] Confirm idle resource cost: `top -pid $(pgrep openwith)` shows < 50MB RSS, ~0% CPU

---

## Phase 5 — Distribution *(deferred — only if Phase 4 earns its keep)*

- [ ] Decide: keep local-only, open-source on GitHub, or Homebrew cask
- [ ] If shipping: code signing, notarization, sparkle/auto-update
- [ ] README, screenshots, example configs

---

## Field notes

*(Use this section while daily-driving. Note anything weird, missing, or worth changing.)*
