# Homebrew Cask formula for Triage.
#
# This file lives in the main Triage repo as a copy-paste TEMPLATE. The actual
# tap that users install from is the separate `homebrew-tap` repo, which holds
# casks for all of jmanuelrosa's macOS apps:
#
#   https://github.com/jmanuelrosa/homebrew-tap
#
# Release flow:
#   1. Tag in this repo, GitHub Actions builds artifacts, attaches to release.
#   2. Read SHA256 of Triage-<version>.zip from the release's SHA256SUMS.txt.
#   3. Copy this file to homebrew-tap/Casks/triage.rb, updating `version`
#      and `sha256`. Commit + push.
#   4. Users: `brew install --cask jmanuelrosa/tap/triage`.

cask "triage" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE_SHA256SUMS_TXT"

  url "https://github.com/jmanuelrosa/triage/releases/download/v#{version}/Triage-#{version}.zip"
  name "Triage"
  desc "Native macOS URL router that silently routes links by rule"
  homepage "https://github.com/jmanuelrosa/triage"

  app "Triage.app"

  # Triage is unsigned during beta. Strip the Gatekeeper quarantine attribute
  # so the app launches without the "cannot be opened" dialog. Remove this
  # block once Triage ships with a Developer ID + notarization.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Triage.app"],
                   sudo: false
  end

  # `brew uninstall --zap` removes user config too. Default uninstall keeps it.
  zap trash: [
    "~/.config/triage",
  ]
end
