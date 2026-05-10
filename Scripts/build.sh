#!/usr/bin/env bash
# Build Triage via SwiftPM and assemble a macOS .app bundle.
# LaunchServices needs a real bundle to register us as a default browser handler;
# a bare CLI binary won't work.

set -euo pipefail
cd "$(dirname "$0")/.."

readonly EXECUTABLE="triage"
readonly BUNDLE="Triage.app"
readonly BUILD_CONFIG="${1:-release}"

# 1. Compile via SwiftPM.
swift build -c "${BUILD_CONFIG}"

# 2. Assemble bundle.
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
cp ".build/${BUILD_CONFIG}/${EXECUTABLE}" "${BUNDLE}/Contents/MacOS/${EXECUTABLE}"
cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"

# 3. Ad-hoc sign so LaunchServices doesn't reject us.
codesign --force --sign - "${BUNDLE}"

echo
echo "Built: $(pwd)/${BUNDLE}"
echo
echo "To install:"
echo "  cp -R ${BUNDLE} /Applications/"
echo "  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/${BUNDLE}"
echo "  open /Applications/${BUNDLE}"
echo "  # then: System Settings → Default web browser → Triage"
echo
echo "To stream logs:"
echo "  log stream --predicate 'subsystem == \"com.jmrosamoncayo.triage\"' --info"
