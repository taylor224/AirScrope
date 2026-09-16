#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-release}"
if [[ ! -f Sources/WiFiCore/Resources/manufacturers.json ]]; then
    print "Preparing the public IEEE manufacturer registry..."
    python3 scripts/update-vendors.py
fi
swift build -c "$configuration" --scratch-path .build
bin_dir="$(swift build -c "$configuration" --scratch-path .build --show-bin-path)"
bundle="${2:-$PWD/build/AirScope.app}"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$bin_dir/WiFiAnalyzer" "$bundle/Contents/MacOS/WiFiAnalyzer.new"
mv -f "$bundle/Contents/MacOS/WiFiAnalyzer.new" "$bundle/Contents/MacOS/WiFiAnalyzer"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp -R Resources/*.lproj "$bundle/Contents/Resources/"
cp Sources/WiFiCore/Resources/manufacturers.json "$bundle/Contents/Resources/manufacturers.json"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
fi
# Local development signing. Set CODESIGN_IDENTITY for a Developer ID build.
codesign --force --sign "${CODESIGN_IDENTITY:--}" --options runtime --entitlements Resources/AirScope.entitlements "$bundle"
codesign --verify --strict "$bundle"
print "Built: $bundle"
