# Security policy

## Why this file matters

Triage runs as the system default browser handler. Every URL you click on macOS passes through it before being routed. That position implies a meaningful trust boundary — a vulnerability here could:

- Exfiltrate the URLs (and source apps) the user clicks
- Redirect the user to a phishing/malicious origin instead of the intended browser
- Persist arbitrary code via tampering with `~/.config/triage/config.yaml` or the bundle on disk

We take reports in this area seriously, even when Triage is in beta and unsigned.

## Supported versions

Triage is pre-1.0. Only the **latest released version** receives security fixes. There is no LTS branch.

| Version    | Supported          |
| ---------- | ------------------ |
| Latest tag | ✅                  |
| Older tags | ❌                  |

## Reporting a vulnerability

**Please do not open a public GitHub issue for security reports.**

Use [GitHub Security Advisories](https://github.com/jmanuelrosa/triage/security/advisories/new) — the *Report a vulnerability* button on the *Security* tab. That gives us a private channel to triage and coordinate disclosure.

If GitHub Security Advisories isn't an option for you, email **jose.moncayo@acme.io** with `[triage security]` in the subject line.

In the report, please include:

- A clear description of the issue and what an attacker could do with it
- Reproduction steps (or a proof-of-concept)
- Triage version (`Triage.app/Contents/Info.plist` → `CFBundleShortVersionString`)
- macOS version and architecture
- Whether the vulnerability is in the binary, the build pipeline, or in a dependency

## Disclosure timeline

- **Acknowledgement**: within 5 business days of receiving the report.
- **Triage decision**: within 14 days — confirm, reject, or request more info.
- **Fix release**: depends on severity. Critical issues aim for a release within 30 days; lower severity may bundle with the next planned release.
- **Public disclosure**: 90 days after the report or 7 days after a fix is released, whichever comes first. We coordinate with reporters who need a different timeline.

We don't currently run a bug bounty. If you'd like attribution, mention that in the report and you'll be credited in the release notes.

## Out of scope

Reports about the following will be closed without action:

- **macOS Gatekeeper warnings on unsigned downloads.** Triage is intentionally unsigned during beta; this is expected behavior, not a vulnerability. The `install.sh` and Homebrew Cask paths strip the quarantine attribute on the user's behalf and that's by design.
- **Path traversal in `~/.config/triage/config.yaml`.** This file is user-authored and trusted by definition.
- **Generic missing-hardening reports** (no PIE, no stack canaries, etc.) without a concrete exploit.
- **Issues in third-party browsers Triage launches.** Report those upstream (Chrome, Helium, etc.).

## Hardening checklist (for our reference)

Items below are tracked but may not all ship in v1:

- [ ] Apple Developer ID code signing + notarization
- [ ] Reproducible builds (deterministic timestamps in the bundle)
- [ ] Sparkle EdDSA-signed update channel
- [ ] Sandboxed config parsing (currently runs in-process)
