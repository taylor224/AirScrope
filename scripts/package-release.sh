#!/bin/zsh
# Build an isolated, universal app and package only that app for distribution.
set -euo pipefail
cd "${0:A:h:h}"
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
version="${1:-$app_version}"
if [[ "$version" != <->.<->.<-> || "$version" != "$app_version" ]]; then
    print -u2 "Release version must match CFBundleShortVersionString ($app_version)."
    exit 1
fi
mkdir -p build/releases
staging="$(mktemp -d "$PWD/build/package.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
bundle="$staging/AirScope.app"
zsh scripts/build.sh release "$bundle" universal
archive="$PWD/build/releases/AirScope-${version}-macOS-universal.zip"
# Exclude extended attributes and resource forks from the download.
ditto -c -k --keepParent --norsrc --noextattr "$bundle" "$archive"
ditto -x -k "$archive" "$staging/verify"
codesign --verify --strict "$staging/verify/AirScope.app"
lipo "$staging/verify/AirScope.app/Contents/MacOS/WiFiAnalyzer" -verify_arch arm64 x86_64
cd build/releases
shasum -a 256 "${archive:t}" > SHA256SUMS.txt
print "Packaged: $archive"
