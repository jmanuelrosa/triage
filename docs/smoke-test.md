# Triage — smoke test

End-to-end validation procedure. Run this before tagging a release, after a clean install on a fresh user account, or whenever something feels off in daily driving.

Time: ~15 minutes. Most steps need a real browser click, so this can't be fully automated.

## Setup

- macOS 13 or later
- Two browsers installed besides Safari (e.g. Chrome with at least two profiles, plus a non-Chrome browser like Helium or Firefox)
- Triage *not* yet set as the system default — the test exercises the first-run path
- A messaging app you can click links from (Slack, Discord, Notes, anything)

If you're re-running on the same machine and want a clean slate:

```sh
rm -rf ~/.config/triage
killall Triage 2>/dev/null
```

Capture the bundle ID of your current default browser before starting, so you can verify the fallback later:

```sh
/usr/bin/python3 -c '
from Foundation import NSWorkspace, NSURL
print(NSWorkspace.sharedWorkspace().URLForApplicationToOpenURL_(NSURL.URLWithString_("http://example.com")).path())
'
```

## Steps

### 1. Install

Pick one path; confirm each install method at least once across releases.

```sh
brew install --cask jmanuelrosa/tap/triage
# or
curl -fsSL https://raw.githubusercontent.com/jmanuelrosa/triage/main/Scripts/install.sh | bash
# or download the DMG, drag to /Applications, right-click → Open the first time
```

**Expect:** `/Applications/Triage.app` exists. Status-bar icon appears (top-right, monochrome). **No** dock icon, **no** main window. `Triage.app` launches without a Gatekeeper block (Homebrew/script strip quarantine; DMG users right-click → Open).

### 2. Set as default browser

Click the menu-bar icon → *Set as Default Web Browser*. macOS pops *"Do you want to use 'Triage' as your default web browser?"* — click **Use 'Triage'**.

**Expect:** menu item flips to *Triage is the Default Web Browser*. No dock flash on subsequent launches.

### 3. First-run fallback capture

```sh
cat ~/.config/triage/fallback-browser.json
```

**Expect:** the file exists, JSON contains the bundle ID of your *previous* default browser (the one you captured in Setup). If Triage somehow ended up as the previous default already, a one-time alert should have fired identifying an inferred sibling — the JSON points at that sibling instead.

### 4. Create a config

Menu → *Open Config File*. An empty template is created at `~/.config/triage/config.yaml`. Replace it with a rule mix that exercises the matcher:

```yaml
browsers:
  personal:
    bundle_id: net.imput.helium      # or any non-Chrome browser you have
  work_general:
    bundle_id: com.google.Chrome
    profile: "Default"
  work_dev:
    bundle_id: com.google.Chrome
    profile: "Profile 4"             # use whatever exists locally; check ~/Library/Application\ Support/Google/Chrome/Local\ State

rules:
  - host: "*.example.com"
    browser: work_dev
  - host: github.com
    path: "/work-org/*"
    browser: work_general
  - source_app: Slack
    browser: work_general
```

Save. **Expect:** no modal alert. (No alert on success is by design — the watcher only speaks up on failure.)

### 5. Host glob match

From Notes or any non-browser app, click `https://api.example.com/health`.

**Expect:** opens in `work_dev` (Chrome, Profile 4 in this example). Verify the Chrome profile avatar in the top-right matches.

### 6. Path glob + Chrome profile resolution

Click `https://github.com/work-org/some-repo` from Notes.

**Expect:** opens in `work_general` (Chrome, Default profile). The profile resolution went from the friendly name in YAML through Chrome's `Local State` JSON to the right directory.

### 7. `source_app` rule

From Slack (or whichever messenger you mapped), click any URL — `https://news.ycombinator.com`, anything *unrelated* to the host rules above.

**Expect:** opens in `work_general` regardless of URL. Source-app rules override URL-based intuition.

### 8. Fallback path

From Notes, click a URL matching no rule, e.g. `https://duckduckgo.com`.

**Expect:** opens in whatever browser is recorded in `fallback-browser.json` (your *previous* default from step 3).

### 9. Config watcher + broken YAML

Edit `~/.config/triage/config.yaml` and corrupt it deliberately (delete a closing quote, add a stray tab, etc.). Save.

**Expect:** modal alert with a plain-text error message. `~/.config/triage/triage.log` has a new timestamped ERROR line:

```sh
tail -5 ~/.config/triage/triage.log
```

Fix the YAML. Save again.

**Expect:** no alert. Clicking a URL works again. No log line on successful parse.

### 10. Loop protection + lifecycle

Add a rule that would route back to Triage itself:

```yaml
rules:
  - host: "loop-test.example"
    browser: triage_self
browsers:
  # ... existing ...
  triage_self:
    bundle_id: com.jmrosamoncayo.triage
```

Click `https://loop-test.example` from Notes.

**Expect:** does *not* open infinitely; falls through to the fallback browser. Check the log if you want confirmation of the loop guard firing.

Remove the loop rule. Then:

- Menu → *Quit*. Click any URL. **Expect:** nothing happens (Triage is gone; macOS finds no registered handler).
- Relaunch via Launchpad. **Expect:** clicking URLs resumes routing immediately. No re-prompt for default-browser status.
- If you have *Launch at Login* checked, reboot. **Expect:** the menu-bar icon reappears within a few seconds of login.

## Idle resource cost

Once steps 1–10 pass and Triage has been idle for ~30 seconds:

```sh
ps -o pid,rss,%cpu,command -p $(pgrep -x Triage)
```

**Expect:** `RSS` < 50 MB (commonly 15–25 MB), `%CPU` ~0.0. If RSS climbs over time across daily-driving, log it in *Field notes* in `TODO.md`.

A heavier snapshot if RSS looks off:

```sh
top -l 1 -pid $(pgrep -x Triage) -stats pid,command,mem,cpu,threads
```

## What to capture if anything fails

Per failure, in *Field notes* in `TODO.md`, record:

- Date
- Step number and short description
- Observed vs expected
- Relevant lines from `~/.config/triage/triage.log`
- Relevant lines from `log stream --predicate 'subsystem == "com.jmrosamoncayo.triage"' --info` (run in another terminal while reproducing)
- Anything unusual about the environment (other running browsers, recent macOS update, etc.)
