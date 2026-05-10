# Triage

> A native macOS menu-bar app that silently routes every clicked link to the right browser — and the right Chrome profile — based on rules you write in a YAML file.

No picker. No dock icon. No Node runtime. ~500 lines of Swift, single-digit MB of RAM at rest.

---

## 🌟 Highlights

- **Rule-based, never asks.** Routes by URL host, path, and source app — first-match-wins. You write the rules once; Triage just obeys.
- **First-class Chrome profile support.** Use friendly names in YAML (`"Work [Dev]"`); Triage resolves them to Chrome's directory names (`Profile 4`) by reading Chrome's own `Local State`.
- **Native, lightweight, invisible.** Pure Swift, no Node/Electron. Status-bar item only — no dock icon, no main window. Sleeping process at rest.
- **Live config reload.** Edit `~/.config/triage/config.yaml`; Triage picks up the change on save. Broken YAML pops a modal alert and writes a plain-text log so you know.
- **Source-app aware.** Match by the app the link came from (`Slack`, `WhatsApp`, …) — useful for "every work-Slack link goes to the work browser, regardless of URL."
- **Silent fallback.** URLs that match no rule open in whatever your previous default browser was at first launch (captured automatically). Configurable via the menu bar.

## ℹ️ Overview

If you use more than one browser — or one browser with multiple profiles — you've felt this: macOS routes every clicked link to the *system default browser*, ignoring where the link came from or where it points. A work Slack link opens in your personal browser. A `github.com/your-employer/...` URL opens in the wrong Chrome profile. You re-route by hand, dozens of times a day.

**Triage** is a small, opinionated macOS background app that fixes this. Set it as your default browser, write a YAML config describing where links *should* go, and forget it. From then on, every clicked link gets routed deterministically:

```
Slack click → kAEGetURL → Triage → match rules → open -na <browser> --args --profile-directory=<profile> <url>
```

The whole thing runs as a status-bar accessory app. It wakes up when a URL arrives, evaluates rules, shells out to the right browser, and goes back to sleep.

## 🆚 How it compares

There are several good tools in this space. Triage exists to fill a specific niche the others don't quite hit:

| Tool                         | Asks before opening?  | Native?            | Chrome profiles? | Cost  | Niche                                                     |
| ---------------------------- | --------------------- | ------------------ | ---------------- | ----- | --------------------------------------------------------- |
| **Triage**                   | ❌ No, rules only      | ✅ Swift            | ✅ First-class    | Free  | Silent rule-based routing, YAML-configured                |
| [Velja][velja]               | ✅ Picker by default   | ✅ Swift            | ⚠️ Limited       | Freemium (Pro upgrade)  | When you *want* to be asked occasionally — rule routing is a Pro feature |
| [Browserosaurus][browserosaurus] | ✅ Picker          | ⚠️ Electron         | ❌                | Free  | Picker-first, cross-platform-ish                          |
| [Finicky][finicky]           | ❌ Rules only          | ✅ Swift + JSCore   | ✅                | Free  | Rule-based, native — but you write rules in JavaScript    |
| [Choosy][choosy]             | Configurable          | ✅                  | ✅                | $12   | Rule-based, native, GUI-configured, paid                  |

[velja]: https://github.com/sindresorhus/Velja
[browserosaurus]: https://browserosaurus.com/
[finicky]: https://github.com/johnste/finicky
[choosy]: https://www.choosyosx.com/

In short: if you want a picker, use Browserosaurus (free) or Velja (free with paid Pro). If you'd rather write rules in JavaScript, Finicky is excellent. If you'll pay for a polished GUI, use Choosy. If you want a tiny native binary you configure in YAML and never see again, that's Triage.

## 🚀 Usage

A minimal config looks like this:

```yaml
browsers:
  personal:
    bundle_id: net.imput.helium
  work_general:
    bundle_id: com.google.Chrome
    profile: "Work"          # human-readable Chrome profile name
  work_dev:
    bundle_id: com.google.Chrome
    profile: "Work [Dev]"

rules:
  # All work domains go to the dev Chrome profile
  - host: "*.example.com"
    browser: work_dev

  # Specific GitHub orgs go to specific places
  - host: github.com
    path: "/work-org/*"
    browser: work_general

  # Anything Slack opens, regardless of URL, goes to the work browser
  - source_app: Slack
    browser: work_general
```

Match rules:

- First matching rule wins, top-down.
- `host`, `path`, `source_app` are all optional. Missing field = match anything.
- `host` and `path` support `*` glob (case-insensitive, anchored both ends).
- `source_app` matches against either the bundle ID (`com.tinyspeck.slackmacgap`) or the app's display name (`Slack`).
- A rule with no `host`/`path`/`source_app` is a valid catch-all.

A live, fuller example with Chrome multi-profile is at [`config.example.yaml`](./config.example.yaml).

## ⬇️ Installation

> **Beta.** No notarized release / Homebrew cask yet — you build it yourself. Tested on macOS 13+, Apple Silicon. ~5 minutes.

**Requirements**
- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`) — the full Xcode is *not* needed

**Build & install**

```bash
git clone https://github.com/jmanuelrosa/triage.git
cd triage
./Scripts/build.sh
cp -R Triage.app /Applications/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Triage.app
open /Applications/Triage.app
```

**Set as default browser**

System Settings → Desktop & Dock → Default web browser → **Triage**.

The first time you click on Triage's menu bar icon → *Open Config File* → the empty template is created at `~/.config/triage/config.yaml`. Edit it; Triage reloads on save.

## ⚙️ Configuration

| File                                          | What it is                                                                          |
| --------------------------------------------- | ----------------------------------------------------------------------------------- |
| `~/.config/triage/config.yaml`                | Your rules. You edit this; Triage only reads.                                       |
| `~/.config/triage/fallback-browser.json`      | Auto-managed. The bundle ID Triage falls back to for URLs matching no rule.         |
| `~/.config/triage/triage.log`                 | Plain-text error log (timestamped). Created on first error.                         |

The fallback browser is captured automatically on first launch — whatever your previous system default was. To change it later, use the menu bar → *Set Fallback Browser*.

## 🩺 Troubleshooting

**A URL went to the wrong browser**

```bash
log stream --predicate 'subsystem == "com.jmrosamoncayo.triage"' --info
```

Click the URL again; you'll see the matched rule (or "no rule matched, using fallback").

**Triage isn't catching URLs at all**

Verify it's the system default:

```bash
plutil -p ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist \
  | grep -A1 LSHandlerURLScheme | grep -B1 -A2 'http[s]\?'
```

You should see `com.jmrosamoncayo.triage` next to `http`/`https`. If not, redo *System Settings → Default web browser → Triage*.

**Config error alert keeps popping up**

```bash
cat ~/.config/triage/triage.log
```

Triage validates YAML at launch and on every save. The log shows the parse error with line/column.

## 🚧 Status

Beta. The author daily-drives it on macOS 26 (Apple Silicon). Specifically:

- ✅ All core features (rule matching, Chrome profiles, fallback, watcher, menu bar) implemented and tested (66 unit tests).
- ✅ No dock icon, no flash on launch.
- ⚠️ No code-signed/notarized release — you build from source. Gatekeeper will warn the first time.
- ⚠️ No auto-update.
- ⚠️ The `open <url>` from Terminal edge case (where the sender PID is `/usr/bin/open` and is gone before we can resolve it) still falls through to the fallback browser instead of using the originating shell.

If you're using it and hit something rough, please file an issue.

## 💭 Contributing

Issues and PRs welcome — especially:

- Bug reports with a `log stream` excerpt
- Documentation fixes
- Cross-platform-ish ideas (e.g., better profile resolution for Edge / Brave / Arc)

For larger changes, please open an issue first so we can talk through the approach.

## 📖 Further reading

- [Yams](https://github.com/jpsim/Yams) — the YAML library Triage uses
- [`man open`](https://ss64.com/osx/open.html) — the underlying launcher (`open -na <bundle> --args --profile-directory=<dir> <url>`)
- [LaunchServices reference](https://developer.apple.com/documentation/coreservices/launch_services) — how the default-browser registration works under the hood

## License

[MIT](./LICENSE) © Jose Manuel Rosa Moncayo
