# AirScope

[English](README.md)

**macOS용 오픈소스 Wi-Fi 분석 앱**입니다. 주변 네트워크의 신호 세기, 잡음, 채널, 보안 방식과 제조사를 확인하고, 신호 이력과 원시 무선 데이터를 살펴볼 수 있습니다.

SwiftUI로 만든 네이티브 앱이며, Apple의 공개 CoreWLAN API를 사용합니다. 외부 Swift 패키지 의존성은 없습니다.

## 주요 기능

| 기능 | 설명 |
| --- | --- |
| 주변 네트워크 | 2.4 / 5 / 6 GHz AP 목록, 정렬, 이름·BSSID·제조사 검색, 대역·보안 필터 |
| 신호 측정 | RSSI, Noise, SNR, 채널·채널 폭, 현재 연결 전송률과 용어 설명 |
| 채널 분포 | AP의 주파수 범위와 신호 세기를 시각화하고 채널 중첩 분석 |
| 신호 이력 | 주변 AP 스캔과 현재 연결의 측정을 구분하여 최대 15분 표시 |
| 제조사 조회 | IEEE MAC 주소 할당 자료를 이용한 오프라인 조회 |
| 원시 데이터 | 비콘·프로브 응답의 Information Element 목록, 해석, 검색, Hex 보기·복사 |
| 보안 분석 | RSN/WPA 정보에서 암호 방식, 인증 방식, 관리 프레임 보호 확인 |
| 워크스페이스 | 현재 필터가 적용된 목록·원시 데이터·신호 이력을 저장하고 나중에 다시 열기 |
| 내보내기 | 원시 바이트와 이력을 포함한 JSON, 네트워크 목록 CSV |
| 설정 | Wi-Fi 어댑터 선택, 5/10/20/30초 스캔 간격, 숨김 네트워크 포함 여부 |
| 언어·테마 | 한국어·영어·간체 중국어, 라이트·다크·시스템 모드 |
| 샘플 모드 | 실제 네트워크 정보 없이 기능을 살펴볼 수 있는 합성 데이터 |

## 다운로드

**[GitHub Releases](https://github.com/taylor224/AirScrope/releases/latest)**에서
`AirScope-<버전>-macOS-universal.zip`을 내려받아 압축을 풀고, `AirScope.app`을
**응용 프로그램**으로 옮기세요.

- macOS 14 이상의 Apple Silicon과 Intel Mac을 지원합니다. 앱 실행에는 Xcode가 필요하지 않습니다.
- 현재 배포본은 **Apple 공증이 없는 ad-hoc 서명 앱**입니다. 첫 실행이 차단되면 신뢰할 수 있는 앱인지 확인한 후 [Apple의 앱 실행 안내](https://support.apple.com/ko-kr/102445)를 따르세요.
- Wi-Fi 이름과 BSSID 조회를 위해 위치 권한을 허용해야 합니다. 위치 좌표는 요청하거나 저장하지 않습니다.
- 다운로드한 ZIP의 무결성을 확인할 수 있는 `SHA256SUMS.txt`를 함께 제공합니다.

## 소스 빌드 요구 사항

- macOS 14 이상
- Swift 6 이상을 제공하는 Xcode
- 빌드에 사용하는 SDK는 Xcode 26.2 이상 권장
- Python 3: 공개 IEEE 제조사 자료 준비에 사용
- 실제 스캔에는 macOS가 지원하는 Wi-Fi 어댑터와 위치 권한 필요

## 빌드 및 실행

```sh
git clone https://github.com/taylor224/AirScrope.git
cd AirScrope
zsh scripts/build.sh release
open build/AirScope.app
```

첫 빌드에서 제조사 데이터가 없으면 IEEE의 공개 자료를 다운로드합니다. 이 단계에는 인터넷 연결이 필요합니다. 생성된 자료와 `.app`은 Git에 포함되지 않습니다.

앱을 실행한 뒤 **권한 허용**을 눌러 macOS 위치 접근을 허용하세요. macOS는 Wi-Fi 이름과 BSSID 조회를 위치 권한으로 보호합니다. 앱은 위치 좌표를 요청하거나 저장하지 않습니다.

샘플 데이터로 실행하려면:

```sh
open build/AirScope.app --args --demo
```

기본 빌드는 로컬 개발용 ad-hoc 서명을 사용합니다. 다시 빌드하면 위치 권한을 재요청할 수 있습니다. 배포용 서명은 `CODESIGN_IDENTITY`로 지정할 수 있으며, Developer ID 인증서와 notarization은 별도로 준비해야 합니다. 공개 소스에는 인증서·개인 서명 정보가 없습니다.

## 사용 방법

1. **주변 네트워크**에서 AP를 선택합니다. 선택은 개요·이력·원시 데이터 화면에 반영됩니다.
2. RSSI·Noise·SNR 등의 **ⓘ** 버튼에서 지표의 의미를 확인합니다.
3. 스캔 버튼 옆 **설정**에서 어댑터, 스캔 간격, 언어, 테마를 변경합니다.
4. **목록 저장**으로 현재 필터 결과와 해당 AP의 이력을 워크스페이스에 저장합니다.
5. **워크스페이스 → 열기**로 저장 당시의 데이터를 다시 봅니다. 저장본을 보는 동안 자동 측정은 정지합니다.
6. **실시간 측정으로 돌아가기**로 새 스캔을 시작합니다.

단축키: `⌘R` 스캔 · `⌘P` 일시 정지/재개 · `⌘E` JSON 내보내기.

## 데이터와 개인정보

- Wi-Fi 측정과 제조사 조회는 Mac 안에서 처리합니다. 관측한 SSID/BSSID를 외부 조회 서비스에 전송하지 않습니다.
- 계정, 광고, 분석용 telemetry 또는 자동 클라우드 업로드가 없습니다.
- 저장·내보내기 전의 측정 이력은 메모리에만 보관합니다.
- 워크스페이스는 `~/Library/Application Support/AirScope/Workspaces/`에 저장됩니다.
- 사용자가 저장한 워크스페이스와 내보내기 파일에는 SSID/BSSID와 측정값이 포함됩니다. 해당 파일은 기본 Git 제외 대상입니다.
- 저장소의 샘플 SSID, 완전한 MAC 주소, 원시 바이트와 측정값은 합성 테스트 데이터입니다. 실제 Wi-Fi 캡처, 개인 경로, 기기 진단 로그, 사용자 설정, 서명 키는 공개하지 않습니다.
- 배포 앱은 GitHub 호스팅 환경에서 버전 태그의 소스로 빌드합니다. 앱과 필수 리소스·라이선스 고지만 패키징합니다.

## 측정값의 의미

- **채널 그래프는 RF 스펙트럼 실측이 아닙니다.** 채널·폭·RSSI로 그린 모델입니다. 중첩 AP 수는 실제 트래픽 혼잡도를 뜻하지 않습니다.
- **Tx rate는 무선 링크 전송률**이며 인터넷 속도나 실제 처리량이 아닙니다.
- **BSS Load는 AP가 보고한 값**이며 Mac이 직접 측정한 채널 사용률이 아닙니다.
- **제조사는 MAC 주소 등록기관**으로, 소비자 브랜드와 다를 수 있습니다. 로컬 관리 주소나 미확인 주소는 추정하지 않습니다.
- 측정되지 않은 값, 가려진 SSID/BSSID, 미제공 IE를 임의로 채우지 않습니다.
- 6 GHz 발견과 반환 데이터는 하드웨어·국가 설정·OS·드라이버에 따라 다릅니다.
- 패킷 캡처, CSI/IQ 수집, 완전한 HE/EHT 디코딩은 지원하지 않습니다.

API 선택과 근거는 [기술 조사 문서](docs/RESEARCH.md)를 참고하세요.

## 개발 및 테스트

```sh
python3 scripts/update-vendors.py
swift test
zsh scripts/build.sh release
```

테스트는 합성 데이터를 사용하며 실제 Wi-Fi 스캔이나 위치 권한이 필요하지 않습니다. GitHub Actions에서도 테스트와 앱 패키징을 실행합니다.

```text
Sources/WiFiAnalyzer/   네이티브 UI, 스캔, 권한, 설정, 언어, 워크스페이스 화면
Sources/WiFiCore/       데이터 모델, IE·보안 파서, 제조사 조회, 진단, 저장·내보내기
Tests/WiFiCoreTests/    파싱·측정·정규화·제조사·워크스페이스 테스트
Resources/             앱 메타데이터, 아이콘, 위치 권한 설명
scripts/               빌드, 배포 패키징, 아이콘 생성, IEEE 자료 갱신
```

제조사 자료는 `python3 scripts/update-vendors.py`로 갱신한 뒤 다시 빌드합니다. Xcode에서 `Package.swift`를 열 수 있습니다. 실제 권한 동작은 빌드 스크립트로 만든 `.app` 번들에서 확인하세요.

## 릴리스 게시

[Release 워크플로](.github/workflows/release.yml)는 태그의 소스로 테스트를 실행하고,
`arm64`와 `x86_64`를 합친 Universal 앱을 빌드합니다. 서명과 압축 파일을 검증한 뒤
ZIP과 SHA-256 체크섬을 GitHub Release에 게시합니다. `GITHUB_TOKEN`을 사용하므로
별도의 개인 토큰이나 서명 비밀 값은 필요하지 않습니다.

1. `Resources/Info.plist`의 `CFBundleShortVersionString`을 변경하고 `CFBundleVersion`을 올립니다.
2. [릴리스 노트](docs/RELEASE_NOTES.md)를 갱신하고 `main`에 커밋·푸시합니다.
3. 앱 버전에 맞는 태그를 생성하고 푸시합니다. 예:

   ```sh
   git tag v1.2.0
   git push origin v1.2.0
   ```

태그는 앱 버전과 동일한 `vMAJOR.MINOR.PATCH` 형식이어야 합니다.
**Actions → Release → Run workflow**에서 기존 태그를 지정해 실행할 수도 있습니다.
이미 게시된 릴리스 파일은 재실행해도 덮어쓰지 않습니다. 업데이트에는 새 버전을 사용하세요.

게시 없이 동일한 패키징을 로컬에서 확인하려면:

```sh
zsh scripts/package-release.sh
```

ZIP과 `SHA256SUMS.txt`는 `build/releases/`에 생성됩니다.

## 기여

버그 제보와 Pull Request를 환영합니다. 재현에는 샘플 모드나 합성 데이터를 사용하고, 실제 네트워크 이름·MAC 주소·위치·장치 로그가 들어간 파일은 첨부하지 마세요. 변경 후 `swift test`와 앱 빌드를 확인해 주세요.

## 라이선스

프로젝트의 소스 코드와 문서는 [MIT License](LICENSE)로 공개합니다. 외부 IEEE 자료와 Apple 플랫폼 구성 요소에 관한 사항은 [NOTICE.md](NOTICE.md)에 정리했습니다.
