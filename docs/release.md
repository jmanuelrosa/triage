# Release checklist

Tag-driven release pipeline. Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds a universal `Triage.app`, packages it as a ZIP and DMG, and attaches both to a GitHub Release. Updating the Homebrew tap is the only step the workflow doesn't automate yet.

## Tap repo

The Homebrew tap lives at [`jmanuelrosa/homebrew-tap`](https://github.com/jmanuelrosa/homebrew-tap) and is the single source of truth for every published cask. Homebrew strips the `homebrew-` prefix, so users run `brew tap jmanuelrosa/tap` and `brew install --cask jmanuelrosa/tap/triage`.

The cask for Triage is `homebrew-tap/Casks/triage.rb`. To add a future app, copy the closest existing cask in the tap and adjust `version`, `sha256`, `url`, `name`, and `app` — there is no template in this repo.

## Per-release steps

1. **Confirm `main` is green.**

   ```sh
   git checkout main && git pull
   swift test
   ```

2. **Cut the release.**

   ```sh
   ./Scripts/release.sh 0.1.1     # or 0.2.0-beta.1, etc.
   ```

   The script bumps `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`, commits, tags `v0.1.1`, and stops short of pushing. It refuses to run on a dirty tree or to overwrite an existing tag.

3. **Push.**

   ```sh
   git push origin main v0.1.1
   ```

   The tag push triggers GitHub Actions. Watch:

   ```sh
   gh run watch
   ```

   Expected artifacts in the new release:
   - `Triage-0.1.1.zip` (used by the cask + `install.sh`)
   - `Triage-0.1.1.dmg` (used by users who download by hand)
   - `SHA256SUMS.txt`

4. **Update the Homebrew cask.**

   Read the SHA from the release:

   ```sh
   gh release view v0.1.1 --json assets -q '.assets[] | select(.name=="SHA256SUMS.txt") | .url' \
     | xargs curl -fsSL
   ```

   Or just open `SHA256SUMS.txt` from the release page and copy the line for `Triage-0.1.1.zip`.

   In the `homebrew-tap` repo, edit `Casks/triage.rb`:

   ```ruby
   version "0.1.1"
   sha256 "<sha-from-SHA256SUMS.txt>"
   ```

   Commit + push.

5. **Smoke-test the install paths.**

   On a Mac without `Triage.app` in `/Applications` (or after `rm -rf /Applications/Triage.app && pkill -x triage`):

   ```sh
   # Path A — Homebrew
   brew uninstall --cask triage 2>/dev/null
   brew install --cask jmanuelrosa/tap/triage

   # Path B — curl|bash
   curl -fsSL https://raw.githubusercontent.com/jmanuelrosa/triage/main/Scripts/install.sh | bash

   # Path C — DMG
   open Triage-0.1.1.dmg   # then drag to Applications, right-click → Open
   ```

   In each case, Triage's status-bar icon should appear in the top-right with no Gatekeeper dialog.

## Notes

- **Pre-releases**: tag with `-beta`, `-rc`, or `-alpha` suffix and the workflow flags the GitHub Release as a pre-release. Homebrew users won't auto-pick it up unless they tap explicitly.
- **Hotfix without a tag bump**: if an artifact is broken, delete the GitHub Release and tag, fix, re-tag the same version. The workflow has no idempotency guards, but `release.sh` does — so you'll need to delete the local tag (`git tag -d v0.1.1`) before re-running.
- **Once notarized**: drop the `postflight` `xattr` block in `Casks/triage.rb` and the `xattr -dr com.apple.quarantine` line in `Scripts/install.sh`. Notarized apps don't need quarantine stripping.
