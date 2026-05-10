#!/usr/bin/env bash
# Triage installer — fetches the latest GitHub release, copies Triage.app to
# /Applications, strips the Gatekeeper quarantine attribute, registers with
# LaunchServices, and launches the app.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jmanuelrosa/triage/main/Scripts/install.sh | bash
#
# Or download and inspect first:
#   curl -fsSL https://raw.githubusercontent.com/jmanuelrosa/triage/main/Scripts/install.sh -o install.sh
#   less install.sh
#   bash install.sh

set -euo pipefail

REPO="jmanuelrosa/triage"
APP_NAME="Triage.app"
INSTALL_DIR="/Applications"

# macOS-only.
if [ "$(uname -s)" != "Darwin" ]; then
    echo "✗ Triage is macOS-only. Detected: $(uname -s)"
    exit 1
fi

# Need /Applications writable. On most personal Macs this is fine; on shared
# machines it may need sudo.
if [ ! -w "${INSTALL_DIR}" ]; then
    echo "✗ ${INSTALL_DIR} is not writable. Re-run with: curl ... | sudo bash"
    exit 1
fi

echo "→ Fetching latest Triage release metadata…"
release_json=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")

asset_url=$(echo "$release_json" \
    | grep -o '"browser_download_url": *"[^"]*\.zip"' \
    | head -1 \
    | sed 's/.*"\(https[^"]*\)"/\1/')

tag=$(echo "$release_json" \
    | grep -o '"tag_name": *"[^"]*"' \
    | head -1 \
    | sed 's/.*"\([^"]*\)"/\1/')

version="${tag#v}"

if [ -z "$asset_url" ]; then
    echo "✗ Could not find a .zip asset in the latest release."
    echo "  Check https://github.com/${REPO}/releases"
    exit 1
fi

echo "→ Latest release: ${tag}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "→ Downloading ${asset_url##*/}…"
curl -fsSL --progress-bar "$asset_url" -o "$tmpdir/Triage.zip"

echo "→ Unpacking…"
ditto -x -k "$tmpdir/Triage.zip" "$tmpdir"

if [ ! -d "$tmpdir/${APP_NAME}" ]; then
    echo "✗ Archive did not contain ${APP_NAME}. Aborting."
    exit 1
fi

if [ -d "${INSTALL_DIR}/${APP_NAME}" ]; then
    echo "→ Replacing existing ${INSTALL_DIR}/${APP_NAME}…"
    rm -rf "${INSTALL_DIR}/${APP_NAME}"
fi
cp -R "$tmpdir/${APP_NAME}" "${INSTALL_DIR}/"

echo "→ Removing Gatekeeper quarantine…"
xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}" 2>/dev/null || true

echo "→ Registering with LaunchServices…"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "${INSTALL_DIR}/${APP_NAME}"

echo "→ Launching Triage…"
open "${INSTALL_DIR}/${APP_NAME}"

cat <<EOF

✓ Installed Triage ${tag}.

  Next:
    1. Set Triage as your default browser:
       System Settings → Desktop & Dock → Default web browser → Triage
    2. Click the Triage icon in the menu bar (top-right) → Open Config File
       to start writing rules. See:
       https://github.com/${REPO}#%EF%B8%8F-configuration

EOF
