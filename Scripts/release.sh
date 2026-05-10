#!/usr/bin/env bash
# Cut a Triage release: bump CFBundleShortVersionString, commit, tag, push.
# The tag push triggers .github/workflows/release.yml which builds artifacts
# and creates the GitHub Release.
#
# Usage:
#   ./Scripts/release.sh 0.1.1
#   ./Scripts/release.sh 0.2.0-beta.1
#
# After the workflow completes, see docs/release.md for the cask-update step.

set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.1.1"
    exit 1
fi

version="$1"
tag="v${version}"
plist="Resources/Info.plist"

# Refuse to release from a dirty tree — releases must be reproducible from
# committed state alone.
if [ -n "$(git status --porcelain)" ]; then
    echo "✗ Working tree is dirty. Commit or stash first."
    git status --short
    exit 1
fi

# Refuse to overwrite an existing tag.
if git rev-parse "$tag" >/dev/null 2>&1; then
    echo "✗ Tag $tag already exists."
    exit 1
fi

current_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")
echo "→ Bumping ${plist}: ${current_version} → ${version}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "$plist"

# CFBundleVersion is the build number — bump as an integer alongside the
# semver string so two releases never share a build number (matters for Sparkle
# later; harmless now).
current_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist")
next_build=$((current_build + 1))
echo "→ Bumping CFBundleVersion: ${current_build} → ${next_build}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${next_build}" "$plist"

git add "$plist"
git commit -m "release: ${tag}"
git tag -a "$tag" -m "Triage ${tag}"

echo
echo "✓ Tagged ${tag}."
echo
echo "Next:"
echo "  git push origin main ${tag}"
echo
echo "The release workflow will fire on the tag push and build artifacts."
echo "After it completes, update the Homebrew cask — see docs/release.md."
