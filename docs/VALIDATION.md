# Validation

## Automated checks

```sh
python3 scripts/update-vendors.py
swift test
zsh scripts/build.sh release
codesign --verify --strict build/AirScope.app
zsh scripts/package-release.sh
```

The Swift Testing suite covers:

- Truncated and malformed information elements, repeated IDs, and bounded parsing.
- RSN/WPA cipher and authentication selectors, management frame protection, and BSS Load.
- Unavailable measurements, channel geometry, and band isolation.
- Duplicate BSSID normalization without merging unrelated access points.
- CSV escaping, JSON raw-byte preservation, and manufacturer attribution.
- Longest-prefix manufacturer lookup and local, group, unknown, or invalid addresses.
- Workspace persistence across repository instances, preserving raw bytes and history.

Tests construct synthetic network records. The public IEEE prefix lookup test
uses a fabricated device-address suffix. No captured network data is required.

## Manual checks

Hardware discovery and location authorization need a supported physical Mac.
UI and device behavior should be checked separately from the automated suite:

- Initial location authorization, denied access, and Wi-Fi disabled states.
- Adapter selection and scan settings while automatic measurements update.
- Search, sorting, selection, measurement explanations, and raw-data inspection.
- Workspace save/reopen, historical timelines, and return to live scanning.
- Language changes and light/dark/system appearance.
- Export dialogs and the contents of files produced by the sample mode.

A successful build or unit-test run does not certify all hardware, locale,
appearance, or location-permission combinations. Release packaging verifies both
CPU architectures and the code signature after extracting the ZIP. App Store
packaging, notarization, and Developer ID signing are outside the automated checks.
