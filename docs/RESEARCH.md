# macOS Wi-Fi data access

AirScope uses Apple's public **CWWiFiClient → CWInterface → CWNetwork** APIs.
Blocking scans run outside the UI's main actor. The app preserves the original
units and bytes returned by the system.

## Official sources

| Source | Application |
| --- | --- |
| [CWInterface](https://developer.apple.com/documentation/corewlan/cwinterface) | Obtain interfaces through CWWiFiClient; read current link measurements. |
| [Network scanning](https://developer.apple.com/documentation/corewlan/cwinterface/scanfornetworks(withssid:includehidden:)) | Scan surrounding networks, optionally including hidden networks. |
| [CWNetwork](https://developer.apple.com/documentation/corewlan/cwnetwork) | Read RSSI, noise, channel, SSID bytes, country, and beacon interval. |
| [Information element data](https://developer.apple.com/documentation/corewlan/cwnetwork/informationelementdata) | Inspect original beacon/probe-response IE bytes. |
| [Transmit rate](https://developer.apple.com/documentation/corewlan/cwinterface/transmitrate()) | Display the current link's PHY rate, not internet throughput. |
| [CWChannel](https://developer.apple.com/documentation/corewlan/cwchannel) | Model channel frequencies and widths. |
| [Apple DTS: SSID access](https://developer.apple.com/forums/thread/732431) | Request location authorization for protected Wi-Fi identifiers. |
| [Apple DTS: BSSID access](https://developer.apple.com/forums/thread/759044) | Use an authorized GUI app rather than a daemon or private airport utility. |
| [Location entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.personal-information.location) | Include location access in hardened-runtime signing. |
| [Location usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationusagedescription) | Explain the permission request in the app bundle. |
| [Apple Wi-Fi recommendations](https://support.apple.com/en-us/102766) | Inform the security guidance shown for legacy configurations. |

## Data interpretation

- Preserve SSID bytes and information-element bytes instead of reconstructing them from labels.
- Treat unavailable RSSI/noise values as unavailable; do not turn zero into excellent reception.
- Compute SNR only when both measurements are valid and RSSI is at least noise.
- Use one coherent observation per BSSID within a scan. Keep different BSSIDs distinct even if their SSIDs match.
- Do not correlate redacted addresses by SSID or invent missing manufacturers.
- Prefer advertised RSN authentication selectors and WPA vendor elements when classifying security. A mixed-mode compatibility query alone does not establish an AP's advertised modes.
- Combine PHY capability queries with returned HT/VHT/HE/EHT information elements where supported.
- BSS Load utilization is an AP-reported byte divided by 255, not a local airtime measurement.
- Channel overlap is a frequency-range model. Noncontiguous 80+80 MHz is not rendered as one continuous block.
- Scan timestamps indicate response processing, not packet-level reception timestamps.

IEEE field interpretation was checked against primary implementation references:
[Linux IEEE 802.11 definitions](https://github.com/torvalds/linux/blob/master/include/linux/ieee80211.h)
and [hostapd/wpa_supplicant selectors](https://w1.fi/wpa_supplicant/devel/wpa__common_8h_source.html).
The parser is implemented in this project; these references are not vendored.

## Manufacturer lookup

The build setup downloads the public [IEEE Registration Authority listings](https://standards.ieee.org/products-programs/regauth/).
The [IEEE EUI/OUI guidelines](https://standards.ieee.org/wp-content/uploads/import/documents/tutorials/eui.pdf)
describe the 24-, 28-, and 36-bit allocation hierarchy.

Lookup checks the most specific prefix first: MA-S/IAB, then MA-M, then MA-L.
Locally administered and group addresses are identified before lookup. A match
identifies the registered organization, which may differ from the device brand.
Observed BSSIDs are never sent to the registry service. See [third-party notices](../NOTICE.md).

## Lower-level capture

Apple documents [Wi-Fi packet traces](https://developer.apple.com/documentation/network/recording-a-wi-fi-packet-trace)
and [packet trace collection](https://developer.apple.com/documentation/network/recording-a-packet-trace)
separately. AirScope does not enable monitor mode or capture packets.

The reviewed public CoreWLAN interfaces do not expose CSI, IQ samples, or spectral
FFT data. Channel graphics therefore represent AP metadata rather than a measured
RF spectrum. Hardware-specific capabilities and SDK availability require separate
validation when expanding support.
