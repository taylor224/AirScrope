## Download

Download `AirScope-<version>-macOS-universal.zip` from the assets below, extract
it, and move **AirScope.app** to **Applications**. The same app supports Apple
silicon and Intel Macs running macOS 14 or later. Xcode is not required.

This build uses ad-hoc signing and is **not notarized by Apple**. If macOS blocks
the first launch, follow Apple's [instructions for opening an app from an
unidentified developer](https://support.apple.com/en-us/102445). Only open the app
if you trust this release. No system-wide security changes are needed.

Allow Location access when the app requests it to read Wi-Fi names and BSSIDs.
AirScope does not request or store location coordinates.

The app includes the public IEEE manufacturer lookup data. It does not include
captured networks, saved workspaces, or developer settings. License and third-party
notices are included in the app bundle.

## Verify the download

Download **SHA256SUMS.txt** into the same folder as the ZIP and run:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

## 한국어

아래 Assets에서 `AirScope-<버전>-macOS-universal.zip`을 내려받아 압축을 풀고,
**AirScope.app**을 **응용 프로그램**으로 옮기세요. macOS 14 이상의 Apple Silicon과
Intel Mac을 지원합니다. Xcode는 필요하지 않습니다.

현재 배포본은 Apple 공증이 없는 ad-hoc 서명 앱입니다. 첫 실행이 차단되면
[Apple의 앱 실행 안내](https://support.apple.com/ko-kr/102445)를 확인하세요.
Wi-Fi 이름과 BSSID 조회를 위해 앱의 위치 권한을 허용해야 하며, 위치 좌표는 수집하지 않습니다.
