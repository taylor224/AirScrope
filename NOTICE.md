# Third-party notices

The project's original source code, documentation, and generated icon artwork
are provided under the [MIT License](LICENSE).

## IEEE MAC assignment data

Manufacturer lookup uses the IEEE Registration Authority's public MA-L, MA-M,
MA-S, and IAB listings. These external datasets are **not included in this Git
repository** and are not relicensed under the project's MIT License.

The build setup downloads the public listings from IEEE and generates a local
lookup file. Dataset provenance and the download date are recorded in that file.
No observed Wi-Fi addresses are submitted to IEEE.

- [IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/)
- [MA-L listing](https://standards-oui.ieee.org/oui/oui.csv)
- [MA-M listing](https://standards-oui.ieee.org/oui28/mam.csv)
- [MA-S listing](https://standards-oui.ieee.org/oui36/oui36.csv)
- [IAB listing](https://standards-oui.ieee.org/iab/iab.csv)

## Apple platform components

SwiftUI, Swift Charts, CoreWLAN, CoreLocation, system fonts, and SF Symbols are
provided by Apple's SDKs or operating system. They are not bundled as third-party
source code or relicensed by this project. AirScope is an independent project
and is not affiliated with Apple or IEEE.
