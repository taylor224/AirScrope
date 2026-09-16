# AirScope

[한국어](README.ko.md)

**An open-source Wi-Fi analyzer for macOS.** Inspect nearby networks, signal
strength, noise, channels, security, and manufacturers. Follow signal history and
explore the raw wireless data available from your Mac.

AirScope is a native SwiftUI app built on Apple's public CoreWLAN API, with no
external Swift package dependencies.

## Download

Get the latest app from **[GitHub Releases](https://github.com/taylor224/AirScrope/releases/latest)**.
Download `AirScope-<version>-macOS-universal.zip`, extract it, and move
`AirScope.app` to **Applications**.

- **macOS 14 or later**, on Apple silicon or Intel. Xcode is not required to run the app.
- Releases currently use **ad-hoc signing and are not notarized by Apple**. If
  macOS blocks the first launch, follow [Apple's instructions](https://support.apple.com/en-us/102445)
  to open an app you trust.
- Allow Location access when prompted to read Wi-Fi names and BSSIDs. AirScope
  does not request or store location coordinates.
- Each release includes `SHA256SUMS.txt` to verify the downloaded ZIP.

## Features

| Feature | Description |
| --- | --- |
| Nearby networks | 2.4 / 5 / 6 GHz access points, sorting, name/BSSID/manufacturer search, band and security filters |
| Signal measurements | RSSI, noise, SNR, channel and width, current link transmit rate, and metric explanations |
| Channel distribution | Visualize frequency ranges and signal levels; inspect overlapping channels |
| Signal history | Up to 15 minutes of observations, distinguishing AP scans from current-link measurements |
| Manufacturer lookup | Offline lookup using public IEEE MAC assignment data |
| Raw data | Browse, decode, search, and copy information elements from beacon/probe responses |
| Security analysis | Inspect RSN/WPA ciphers, authentication methods, and management frame protection |
| Workspaces | Save the filtered network list, raw data, and signal history for later review |
| Export | JSON with raw bytes and history, or a CSV network list |
| Settings | Wi-Fi adapter selection, 5/10/20/30-second scan intervals, and hidden-network scanning |
| Languages and appearance | English, Korean, Simplified Chinese; light, dark, or system appearance |
| Demo mode | Explore the app with synthetic data instead of real network observations |

## Build from source

Requirements: macOS 14 or later, Xcode with Swift 6 or later, and Python 3 for
preparing the public manufacturer registry. Xcode 26.2 or later is recommended
for the build SDK. Scanning requires a Wi-Fi adapter supported by macOS.

```sh
git clone https://github.com/taylor224/AirScrope.git
cd AirScrope
zsh scripts/build.sh release
open build/AirScope.app
```

The first build downloads public manufacturer data from IEEE if it is missing.
That step requires an internet connection. Generated data and app bundles are
excluded from Git.

To explore synthetic data:

```sh
open build/AirScope.app --args --demo
```

Local builds use ad-hoc signing and may request Location access again after a
rebuild. Set `CODESIGN_IDENTITY` for a Developer ID build; a certificate and Apple
notarization must be arranged separately. No signing credentials are included in
the repository or required by the release workflow.

## Using AirScope

1. Select an AP in **Nearby Networks**. The selection is shared across the overview, history, and raw-data views.
2. Use the **ⓘ** buttons beside metrics such as RSSI, noise, and SNR to see their meaning.
3. Open **Settings** beside the scan button to change the adapter, interval, language, or appearance.
4. Use **Save List** to save the current filtered networks and their history to a workspace.
5. Open a saved workspace to review its original observations. Automatic measurements pause while you view a snapshot.
6. Return to live measurements to resume scanning.

Shortcuts: `⌘R` scan · `⌘P` pause/resume · `⌘E` export JSON.

## Data and privacy

- Wi-Fi analysis and manufacturer lookup run locally. Observed SSIDs and BSSIDs are not sent to external lookup services.
- There are no accounts, ads, analytics telemetry, or automatic cloud uploads.
- Measurement history stays in memory until you save or export it.
- Workspaces are stored in `~/Library/Application Support/AirScope/Workspaces/`.
- Saved workspaces and exports contain network identifiers and measurements. These files are excluded from Git by default.
- Sample SSIDs, full MAC addresses, raw bytes, and measurements in the repository are synthetic. Real captures, personal paths, device diagnostics, user settings, and signing keys are excluded from the public source and release packaging.
- Downloadable apps are built on GitHub-hosted runners from tagged source. Packaging includes only the app and its required resources and license notices.

## Understanding the measurements

- **Channel charts are modeled from channel, width, and RSSI.** They are not measured RF spectra. The number of overlapping APs does not measure actual traffic congestion.
- **Tx rate is the wireless PHY link rate**, not internet speed or application throughput.
- **BSS Load is reported by the AP**, not a channel-utilization measurement taken by your Mac.
- **Manufacturer identifies the MAC assignment holder**, which may differ from the consumer brand. Locally administered and unknown addresses are not guessed.
- Missing measurements, redacted SSIDs/BSSIDs, and unavailable information elements are not fabricated.
- 6 GHz discovery and the available data depend on hardware, regulatory settings, macOS, and drivers.
- Packet capture, CSI/IQ collection, and complete HE/EHT decoding are not supported.

See the [API research notes](docs/RESEARCH.md) for sources and implementation decisions.

## Development and testing

```sh
python3 scripts/update-vendors.py
swift test
zsh scripts/build.sh release
```

Tests use synthetic data and require neither a live Wi-Fi scan nor Location
access. GitHub Actions runs tests and app packaging on branch pushes and pull
requests.

```text
Sources/WiFiAnalyzer/   Native UI, scans, permissions, settings, localization, workspaces
Sources/WiFiCore/       Models, IE/security parsing, manufacturer lookup, analysis, persistence
Tests/WiFiCoreTests/    Parsing, measurements, normalization, manufacturer, workspace tests
Resources/             App metadata, icon, localized permission descriptions
scripts/               Build, packaging, icon generation, IEEE registry updates
```

Refresh the registry with `python3 scripts/update-vendors.py`, then rebuild the
app. You can open `Package.swift` in Xcode. Check real permission behavior using
the `.app` bundle produced by the build script.

## Publishing a release

The [Release workflow](.github/workflows/release.yml) tests the tagged source,
builds both `arm64` and `x86_64`, combines them into a universal app, verifies its
signature and ZIP contents, and publishes the ZIP and SHA-256 checksum to GitHub
Releases. It uses `GITHUB_TOKEN`; no personal token or signing secret is needed.

1. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Resources/Info.plist`.
2. Update [release notes](docs/RELEASE_NOTES.md), commit, and push to `main`.
3. Create and push a matching version tag, for example:

   ```sh
   git tag v1.2.0
   git push origin v1.2.0
   ```

The tag must use `vMAJOR.MINOR.PATCH` and match the app version. You can also run
**Actions → Release → Run workflow** with an existing version tag. Published
release assets are kept unchanged on a rerun; use a new version for an update.

To check the same packaging locally without publishing:

```sh
zsh scripts/package-release.sh
```

The ZIP and `SHA256SUMS.txt` are written to `build/releases/`.

## Contributing

Issues and pull requests are welcome. Use demo mode or synthetic data for
reproductions, and avoid attaching real network names, MAC addresses, locations,
or device logs. Run `swift test` and the app build after making changes.

## License

Source code and documentation are released under the [MIT License](LICENSE).
See [NOTICE.md](NOTICE.md) for IEEE data and Apple platform notices.
