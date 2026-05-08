#!/usr/bin/env bash
# Build the openwith POC into a proper macOS .app bundle.
# LaunchServices needs a real bundle to register us as a default browser handler;
# a bare CLI binary won't work.

set -euo pipefail
cd "$(dirname "$0")"

readonly APP_NAME="openwith-poc"
readonly BUNDLE="${APP_NAME}.app"

# 1. Compile (host arch; bump deployment target to macOS 13 for Logger).
xcrun swiftc \
    -O \
    -framework AppKit \
    main.swift \
    -o "${APP_NAME}"

# 2. Assemble bundle.
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mv "${APP_NAME}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${BUNDLE}/Contents/Info.plist"

# 3. Ad-hoc sign so LaunchServices doesn't reject us.
codesign --force --sign - "${BUNDLE}"

echo
echo "Built: $(pwd)/${BUNDLE}"
echo
echo "Next:"
echo "  1. Move to /Applications:"
echo "       cp -R ${BUNDLE} /Applications/"
echo "  2. Open it once so LaunchServices registers it:"
echo "       open /Applications/${BUNDLE}"
echo "  3. System Settings → Desktop & Dock → Default web browser → openwith POC"
echo "  4. Stream logs in another terminal:"
echo "       log stream --predicate 'subsystem == \"openwith.poc\"' --info"
echo "  5. Click links from Slack, Messages, Mail, Notes, Terminal (\`open https://example.com\`),"
echo "     Safari address bar — watch the log for url + frontmost + menuBarOwner."
echo
echo "To uninstall:"
echo "       rm -rf /Applications/${BUNDLE}"
echo "       (then reset default browser in System Settings)"
