#!/usr/bin/env bash
# Build Triage via SwiftPM and assemble a macOS .app bundle.
# LaunchServices needs a real bundle to register us as a default browser handler;
# a bare CLI binary won't work.
#
# Usage:
#   ./Scripts/build.sh                      # release config, native arch only
#   ./Scripts/build.sh debug                # debug config, native arch only
#   UNIVERSAL=1 ./Scripts/build.sh release  # release config, universal arm64 + x86_64
#                                           # (requires full Xcode; CLT-only setups
#                                           # will fail with an xcbuild error)

set -euo pipefail
cd "$(dirname "$0")/.."

readonly EXECUTABLE="triage"
readonly BUNDLE="Triage.app"
readonly BUILD_CONFIG="${1:-release}"
readonly UNIVERSAL="${UNIVERSAL:-0}"

# Universal binary opt-in — `swift build --arch arm64 --arch x86_64` requires
# xcbuild from full Xcode, which isn't present on Command Line Tools-only
# machines. CI (full Xcode) sets UNIVERSAL=1; local CLT-only builds default to
# native single-arch, which still produces a working .app for that machine.
swift_args=(build -c "${BUILD_CONFIG}")
if [ "${UNIVERSAL}" = "1" ]; then
    swift_args+=(--arch arm64 --arch x86_64)
fi

# 1. Compile.
swift "${swift_args[@]}"

# 2. Locate the binary. SwiftPM puts multi-arch builds under
#    .build/apple/Products/<Config>/ (with a capitalized config name) instead of
#    the usual .build/<config>/. Probe both. Hardcode the capitalized form
#    rather than using ${var^} since macOS ships bash 3.2 which doesn't support it.
case "${BUILD_CONFIG}" in
    debug)   capitalized="Debug" ;;
    release) capitalized="Release" ;;
    *)       capitalized="${BUILD_CONFIG}" ;;
esac
binary_paths=(
    ".build/apple/Products/${capitalized}/${EXECUTABLE}"
    ".build/${BUILD_CONFIG}/${EXECUTABLE}"
)
binary=""
for candidate in "${binary_paths[@]}"; do
    if [ -f "${candidate}" ]; then
        binary="${candidate}"
        break
    fi
done
if [ -z "${binary}" ]; then
    echo "✗ Could not locate built binary. Looked in:"
    printf '    %s\n' "${binary_paths[@]}"
    exit 1
fi

# 3. Assemble bundle.
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
cp "${binary}" "${BUNDLE}/Contents/MacOS/${EXECUTABLE}"
cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"

# 4. Ad-hoc sign so LaunchServices doesn't reject us. Replaced by Developer ID
#    signing once notarization is enabled (see docs/release.md).
codesign --force --sign - "${BUNDLE}"

echo
echo "Built: $(pwd)/${BUNDLE}"
echo "Architectures: $(lipo -archs "${BUNDLE}/Contents/MacOS/${EXECUTABLE}")"
echo
echo "To install:"
echo "  cp -R ${BUNDLE} /Applications/"
echo "  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/${BUNDLE}"
echo "  open /Applications/${BUNDLE}"
echo "  # then: System Settings → Default web browser → Triage"
echo
echo "To stream logs:"
echo "  log stream --predicate 'subsystem == \"com.jmrosamoncayo.triage\"' --info"
