#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-release}"
architecture="${3:-native}"
case "$architecture" in
    native|universal) ;;
    *) print -u2 "Architecture must be native or universal."; exit 1 ;;
esac
if [[ ! -f Sources/WiFiCore/Resources/manufacturers.json ]]; then
    print "Preparing the public IEEE manufacturer registry..."
    python3 scripts/update-vendors.py
fi
bundle="${2:-$PWD/build/AirScope.app}"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
if [[ "$architecture" == universal ]]; then
    binaries=()
    for arch in arm64 x86_64; do
        scratch=".build/universal/$arch"
        swift build -c "$configuration" --scratch-path "$scratch" --arch "$arch"
        bin_dir="$(swift build -c "$configuration" --scratch-path "$scratch" --arch "$arch" --show-bin-path)"
        binaries+=("$bin_dir/WiFiAnalyzer")
    done
    lipo -create "${binaries[@]}" -output "$bundle/Contents/MacOS/WiFiAnalyzer.new"
    lipo "$bundle/Contents/MacOS/WiFiAnalyzer.new" -verify_arch arm64 x86_64
else
    swift build -c "$configuration" --scratch-path .build
    bin_dir="$(swift build -c "$configuration" --scratch-path .build --show-bin-path)"
    cp "$bin_dir/WiFiAnalyzer" "$bundle/Contents/MacOS/WiFiAnalyzer.new"
fi
if [[ "$configuration" == release ]]; then
    strip -S "$bundle/Contents/MacOS/WiFiAnalyzer.new"
fi
mv -f "$bundle/Contents/MacOS/WiFiAnalyzer.new" "$bundle/Contents/MacOS/WiFiAnalyzer"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp -R Resources/*.lproj "$bundle/Contents/Resources/"
cp Sources/WiFiCore/Resources/manufacturers.json "$bundle/Contents/Resources/manufacturers.json"
cp LICENSE "$bundle/Contents/Resources/LICENSE.txt"
cp NOTICE.md "$bundle/Contents/Resources/NOTICE.md"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
fi
# Local development signing. Set CODESIGN_IDENTITY for a Developer ID build.
codesign --force --sign "${CODESIGN_IDENTITY:--}" --options runtime --entitlements Resources/AirScope.entitlements "$bundle"
codesign --verify --strict "$bundle"
print "Built: $bundle"
