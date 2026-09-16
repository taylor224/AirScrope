import SwiftUI
import WiFiCore

enum WorkspacePage: String, CaseIterable {
    case overview = "개요", networks = "주변 네트워크", history = "신호 이력", raw = "원시 데이터", workspaces = "워크스페이스"

}

struct ContentView: View {
    @ObservedObject var store: WiFiStore
    @State private var page: WorkspacePage = .overview
    @State private var showDetails = false
    @State private var showSettings = false
    @State private var pendingSave: SavedWorkspace?
    @State private var settingsInterfaces: [String] = []
    @State private var settingsInterface: String?
    @State private var settingsInterval = 10.0
    @State private var settingsHidden = true
    @State private var sortOrder = [KeyPathComparator(\NetworkRecord.rssi, order: .reverse)]
    var body: some View {
        VStack(spacing: 0) {
            navigation
            toolbar
            if store.isDemo && store.workspace == nil { notice("데모 모드", detail: "네트워크와 측정값은 샘플 데이터입니다.", action: "실제 Wi-Fi로 전환", perform: store.switchMode) }
            if !store.authorized && !store.isDemo && store.workspace == nil {
                notice("Wi-Fi 이름 조회를 위한 위치 접근", detail: "SSID와 BSSID를 읽는 데 필요합니다. 위치 좌표는 수집하지 않습니다.",
                       action: store.authorization == .notDetermined ? "권한 허용" : "위치 설정 열기") {
                    if store.authorization == .notDetermined { store.requestAccess() } else { store.openLocationSettings() }
                }
            }
            if let workspace = store.workspace {
                notice("저장된 목록", detail: workspace.name, action: "실시간 측정으로 돌아가기", perform: store.resumeLive)
            }
            if let error = store.error { notice("측정 안내", detail: error, action: "닫기") { store.error = nil } }
            Group {
                switch page {
                case .overview: overview
                case .networks: networkWorkspace
                case .history: historyWorkspace
                case .raw: rawWorkspace
                case .workspaces: WorkspaceListView(store: store) { page = .networks }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            statusBar
        }.background(Theme.canvas).foregroundStyle(Theme.ink).tint(Theme.blue)
            .sheet(isPresented: $showSettings) {
                SettingsView(interfaces: settingsInterfaces, currentInterface: settingsInterface, interval: settingsInterval, hidden: settingsHidden) { name, interval, hidden in
                    let changed = store.interfaceName != name
                    store.interfaceName = name; store.scanInterval = interval; store.includeHidden = hidden
                    if changed { store.changeInterface() }
                }
            }
            .sheet(item: $pendingSave) { snapshot in
                SaveWorkspaceView(snapshot: snapshot) { page = .workspaces }
            }
            .sheet(isPresented: $showDetails) {
                VStack(spacing: 0) {
                    HStack {
                        Text(L("네트워크 상세")).font(.system(size: 21, weight: .semibold))
                        Spacer()
                        Button(L("완료")) { showDetails = false }.buttonStyle(PillButton(primary: true)).keyboardShortcut(.cancelAction)
                    }.padding(24)
                    NetworkDetailsView(network: store.selected, isDemo: store.isDemo)
                }.frame(width: 780, height: 620).background(Theme.parchment)
            }
            .onChange(of: store.filtered.map(\.id)) { _, ids in
                if !ids.contains(store.selectedID ?? "") { store.selectedID = ids.first }
            }
    }
    private var navigation: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "wifi").font(.system(size: 17, weight: .semibold))
                Text("AirScope").font(.system(size: 17, weight: .semibold)).tracking(-0.3)
            }.padding(.leading, 78).frame(width: 210, alignment: .leading)
            Spacer()
            HStack(spacing: 30) {
                ForEach(WorkspacePage.allCases, id: \.self) { item in
                    Button { page = item } label: {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Text(L(item.rawValue)).font(.system(size: 12, weight: page == item ? .semibold : .regular))
                                .foregroundStyle(page == item ? Color.white : Theme.darkMuted)
                            Spacer(minLength: 0)
                            Rectangle().fill(page == item ? Theme.blueOnDark : .clear).frame(height: 2)
                        }.frame(height: 44)
                    }.buttonStyle(PressButton()).accessibilityAddTraits(page == item ? .isSelected : [])
                }
            }
            Spacer()
            Color.clear.frame(width: 150, height: 1)

        }.frame(height: 44).background(Color.black)
    }
    private var toolbar: some View {
        HStack(spacing: 22) {
            Text(L("Wi-Fi 분석")).font(.system(size: 21, weight: .semibold)).tracking(-0.3)
            Spacer()
            Button { store.toggleRunning() } label: {
                Label(L(store.isRunning ? "일시 정지" : "다시 시작"), systemImage: store.isRunning ? "pause" : "play")
            }.buttonStyle(LinkButton()).font(.system(size: 12)).disabled(store.workspace != nil).help(L("자동 측정 정지 / 시작 · ⌘P"))
            Button {
                let records = store.filtered.sorted(using: sortOrder)
                let ids = Set(records.map(\.id))
                pendingSave = SavedWorkspace(name: "", isDemo: store.isDemo, networks: records,
                    history: store.history.filter { ids.contains($0.networkID) }, link: store.link, selectedID: store.selectedID)
            } label: { Label(L("목록 저장"), systemImage: "folder.badge.plus").font(.system(size: 12)) }
                .buttonStyle(LinkButton()).disabled(store.filtered.isEmpty)
            Menu {
                Button(L("JSON · 원시 데이터와 이력")) { store.export(json: true) }
                Button(L("CSV · 현재 네트워크 목록")) { store.export(json: false) }
            } label: { Label(L("내보내기"), systemImage: "square.and.arrow.up").font(.system(size: 12)) }.menuStyle(.borderlessButton).fixedSize()
            Button { store.scan() } label: {
                Label(L(store.isScanning ? "스캔 중…" : "지금 스캔"), systemImage: "arrow.clockwise")
            }.buttonStyle(PillButton(primary: true)).disabled(store.isScanning || store.workspace != nil || (!store.isDemo && !store.authorized))
            Button {
                settingsInterfaces = store.interfaces; settingsInterface = store.interfaceName
                settingsInterval = store.scanInterval; settingsHidden = store.includeHidden; showSettings = true
            } label: { Image(systemName: "gearshape").font(.system(size: 17)).frame(width: 32, height: 40) }
                .buttonStyle(LinkButton()).help(L("설정")).accessibilityLabel(L("설정"))
        }.padding(.horizontal, 40).frame(height: 64).background(Theme.parchment)
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }
    private func notice(_ title: String, detail: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle").foregroundStyle(Theme.blue)
            Text(L(title)).font(.system(size: 13, weight: .semibold))
            Text(L(detail)).font(.system(size: 12)).foregroundStyle(Theme.secondary).lineLimit(2)
            Spacer(minLength: 8)
            Button(L(action), action: perform).buttonStyle(LinkButton()).font(.system(size: 13))
        }.padding(.horizontal, 40).padding(.vertical, 12).background(Theme.pearl)
    }
    private var overview: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("채널 분포")).font(.system(size: 34, weight: .semibold)).tracking(-0.37)
                            Text(L("주변 AP가 사용하는 주파수와 신호 세기를 함께 살펴보세요."))
                                .font(.system(size: 17)).foregroundStyle(Theme.darkMuted)
                        }
                        Spacer()
                        Button { page = .networks } label: { Label(L("네트워크 보기"), systemImage: "chevron.right") }
                            .buttonStyle(LinkButton(onDark: true)).font(.system(size: 14)).padding(.top, 12)
                    }
                    SpectrumView(networks: store.networks, selectedID: $store.selectedID)
                        .frame(height: 260)
                }.padding(.vertical, 40).pageContent().foregroundStyle(.white).background(Theme.dark)
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("신호 분석")).font(.system(size: 34, weight: .semibold)).tracking(-0.37)
                            Text(L("선택한 네트워크의 측정값을 바탕으로 분석합니다.")).font(.system(size: 17)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button(L("상세 정보 보기")) { showDetails = true }.buttonStyle(PillButton()).disabled(store.selected == nil)
                    }
                    InsightsView(network: store.selected, networks: store.networks, history: store.history)
                }.padding(.vertical, 48).pageContent().background(Theme.parchment)
            }
        }.scrollIndicators(.hidden)
    }
    private var hero: some View {
        VStack(spacing: 28) {
            HStack(alignment: .center, spacing: 60) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("선택한 네트워크")).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    Text(store.selected.map(networkTitle) ?? "Wi-Fi")
                        .font(.system(size: 48, weight: .semibold)).tracking(-0.37).lineLimit(2).minimumScaleFactor(0.7).textSelection(.enabled)
                    Text(heroDescription).font(.system(size: 17)).foregroundStyle(Theme.muted).lineSpacing(8)
                    if let n = store.selected {
                        HStack(spacing: 16) {
                            Text(n.band.rawValue)
                            Text(L("채널 {0}", String(n.channel)))
                            Text(n.widthMHz.map { "\($0) MHz" } ?? L("채널 폭 미확인"))
                        }.font(.system(size: 14)).foregroundStyle(Theme.secondary).padding(.top, 4)
                        Button { page = .networks } label: { Label(L("다른 네트워크 살펴보기"), systemImage: "chevron.right") }
                            .buttonStyle(LinkButton()).font(.system(size: 14)).padding(.top, 4)
                    } else {
                        Button(L("데모 살펴보기")) { if !store.isDemo { store.switchMode() } }.buttonStyle(PillButton())
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                SignalHero(network: store.selected).frame(width: 260, height: 210)
            }
            HStack(spacing: 0) {
                heroMetric("주변 네트워크", value: "\(store.networks.count)", unit: "APs", detail: "현재 스캔에서 관측")
                Theme.line.frame(width: 1, height: 62)
                heroMetric("신호 대 잡음비", value: store.selected?.snr.map(String.init) ?? "—", unit: "dB", detail: "선택 AP의 RSSI − noise")
                Theme.line.frame(width: 1, height: 62)
                heroMetric("현재 연결 Tx rate", value: (store.link?.transmitRateMbps ?? 0) > 0 ? String(format: "%.0f", store.link!.transmitRateMbps) : "—", unit: "Mbps", detail: "Mac의 PHY 링크 속도")
            }
        }.padding(.vertical, 36).pageContent().background(Theme.canvas)
    }
    private var heroDescription: String {
        guard let n = store.selected else { return "" }
        let vendor = manufacturerLabel(n.manufacturer)
        return "\(vendor) · \(n.security)"
    }
    private func heroMetric(_ title: String, value: String, unit: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L(title)).font(.system(size: 12)).foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.system(size: 34, weight: .semibold)).tracking(-0.4).monospacedDigit()
                Text(unit).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Text(L(detail)).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }.frame(maxWidth: .infinity, alignment: .center)
    }
    private var networkWorkspace: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeading("주변 네트워크", subtitle: L("{0}개 네트워크", String(store.networks.count)))
            HStack(spacing: 10) {
                FilterChip(title: "전체", count: store.networks.count, selected: store.bandFilter == nil) { store.bandFilter = nil }
                ForEach([WiFiBand.two, .five, .six], id: \.self) { band in
                    FilterChip(title: band.rawValue, count: store.networks.filter { $0.band == band }.count, selected: store.bandFilter == band) { store.bandFilter = band }
                }
                Spacer(minLength: 12)
                Picker(L("보안"), selection: $store.securityFilter) {
                    Text(L("모든 보안")).tag("전체"); Text(L("보안 설정됨")).tag("Secure"); Text(L("암호화 없음")).tag("Open")
                }.labelsHidden().frame(width: 140)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField(L("이름, 제조사, BSSID 검색"), text: $store.search).textFieldStyle(.plain)
                    if !store.search.isEmpty { Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(LinkButton()).accessibilityLabel(L("검색 지우기")) }
                }.font(.system(size: 14)).padding(.horizontal, 16).frame(width: 260, height: 44).background(Theme.canvas, in: Capsule()).overlay(Capsule().stroke(Theme.line))
            }
            VStack(spacing: 0) {
                if store.filtered.isEmpty {
                    EmptyState(symbol: "wifi", title: store.networks.isEmpty ? "스캔을 기다리고 있습니다" : "검색 결과가 없습니다", detail: store.networks.isEmpty ? "위치 권한과 Wi-Fi 상태를 확인하세요." : "검색어 또는 대역과 보안 필터를 변경해 보세요.")
                } else {
                    HStack(spacing: 24) {
                        ForEach(["RSSI", "Noise", "SNR", "Tx rate", "Channel", "Width"], id: \.self) { term in
                            HStack(spacing: 6) { Text(termTitle(term)); TermInfo(term: term) }
                        }
                        Spacer()
                        HStack(spacing: 6) { Text(L("제조사")); TermInfo(term: "Manufacturer") }
                    }.font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.horizontal, 20).padding(.vertical, 12)
                    networkTable
                }
                HStack {
                    Text(L("{0}개 표시", String(store.filtered.count))).foregroundStyle(Theme.muted)
                    Spacer()
                    Text(L("행을 선택하면 개요·이력·원시 데이터에 반영됩니다.")).foregroundStyle(Theme.muted)
                    Button(L("선택 AP 상세")) { showDetails = true }.buttonStyle(LinkButton()).disabled(store.selected == nil)
                }.font(.system(size: 12)).padding(16).background(Theme.pearl)
            }.utilityCard().clipShape(RoundedRectangle(cornerRadius: 18))
            selectedStrip
        }.padding(.vertical, 28).pageContent().background(Theme.parchment)
    }
    private var networkTable: some View {
        Table(store.filtered.sorted(using: sortOrder), selection: $store.selectedID, sortOrder: $sortOrder) {
            TableColumn(L("네트워크"), value: \NetworkRecord.name) { n in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(networkTitle(n)).fontWeight(n.isConnected ? .semibold : .regular).lineLimit(1)
                        if n.isConnected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.blue).font(.system(size: 11)) }
                    }
                    Text(n.bssid ?? L("주소 미제공")).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
                }.padding(.vertical, 7)
            }.width(min: 180, ideal: 225)
            TableColumn(L("제조사"), value: \NetworkRecord.manufacturerName) { n in Text(manufacturerLabel(n.manufacturer)).lineLimit(2).help(n.manufacturerName) }.width(min: 115, ideal: 155)
            TableColumn("RSSI", value: \NetworkRecord.rssi) { n in
                HStack(spacing: 10) { SignalBars(value: n.validRSSI); Text(n.validRSSI.map { "\($0)" } ?? "—").monospacedDigit() }
            }.width(86)
            TableColumn("Noise", value: \NetworkRecord.noise) { n in Text(n.validNoise.map(String.init) ?? "—").monospacedDigit().foregroundStyle(Theme.muted) }.width(52)
            TableColumn("SNR") { n in Text(n.snr.map { "\($0) dB" } ?? "—").monospacedDigit() }.width(55)
            TableColumn(L("채널"), value: \NetworkRecord.channel) { n in Text("\(n.channel)").monospacedDigit() }.width(44)
            TableColumn(L("폭")) { n in Text(n.widthMHz.map { "\($0) MHz" } ?? "—") }.width(64)
            TableColumn(L("대역")) { n in Text(n.band.rawValue) }.width(65)
            TableColumn(L("보안"), value: \NetworkRecord.security) { n in Text(n.security).lineLimit(2) }.width(min: 110, ideal: 140)
        }.font(.system(size: 13)).tableStyle(.inset(alternatesRowBackgrounds: false)).scrollContentBackground(.hidden)
    }
    private var selectedStrip: some View {
        HStack(spacing: 24) {
            Image(systemName: "wifi").font(.system(size: 24, weight: .light)).foregroundStyle(Theme.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.selected.map(networkTitle) ?? L("네트워크를 선택하세요")).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                Text(store.selected.map { manufacturerLabel($0.manufacturer) } ?? "").font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            Button(L("신호 이력 보기")) { page = .history }.buttonStyle(LinkButton())
            Button(L("원시 데이터 보기")) { page = .raw }.buttonStyle(PillButton())
        }.font(.system(size: 14)).padding(20).utilityCard()
    }
    private var historyWorkspace: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                pageHeading("신호 이력", subtitle: "RSSI와 noise의 변화를 시간에 따라 확인하세요.")
                Spacer(); networkPicker.padding(.top, 12)
            }
            HistoryView(network: store.selected, samples: store.history, referenceDate: store.workspace?.savedAt).padding(24).utilityCard()
            selectedStrip
        }.padding(.vertical, 32).pageContent().background(Theme.parchment)
    }
    private var rawWorkspace: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                pageHeading("원시 데이터", subtitle: "비콘과 프로브 응답의 Information Element를 직접 읽습니다.")
                Spacer(); networkPicker.padding(.top, 12)
            }
            HStack(spacing: 32) {
                rawMetric("선택한 AP", store.selected.map(networkTitle) ?? "—")
                rawMetric("원본 크기", "\(store.selected?.informationElements?.count ?? 0) bytes")
                rawMetric("Information Elements", "\(store.selected?.elements.elements.count ?? 0)")
                rawMetric("제조사 · IEEE 등록기관", store.selected.map { manufacturerLabel($0.manufacturer) } ?? "—")
            }.padding(24).utilityCard()
            RawDataView(network: store.selected).utilityCard().clipShape(RoundedRectangle(cornerRadius: 18))
        }.padding(.vertical, 32).pageContent().background(Theme.parchment)
    }
    private func rawMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(title)).font(.system(size: 12)).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: 17, weight: .semibold)).lineLimit(2).textSelection(.enabled)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var networkPicker: some View {
        Menu {
            ForEach(store.networks) { n in Button("\(networkTitle(n)) · \(n.band.rawValue) · \(n.bssid ?? L("주소 미제공"))") { store.selectedID = n.id } }
        } label: { Label(store.selected.map(networkTitle) ?? L("네트워크 선택"), systemImage: "wifi").font(.system(size: 14)).lineLimit(1) }
            .menuStyle(.borderlessButton).frame(width: 240)
    }
    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L(title)).font(.system(size: 40, weight: .semibold)).tracking(-0.37)
            Text(L(subtitle)).font(.system(size: 17)).foregroundStyle(Theme.muted)
        }
    }
    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(store.isRunning ? Theme.blue : Theme.muted).frame(width: 5, height: 5)
            Text(store.workspace != nil ? L("저장된 목록") : store.isScanning ? L("스캔 중…") : store.isRunning ? L("자동 측정 · {0}초 간격", String(Int(store.scanInterval))) : L("일시 정지"))
            Spacer()
            if let last = store.lastScan { Text(L("마지막 스캔 {0}", last.formatted(date: .omitted, time: .standard))) }

        }.font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.horizontal, 32).frame(height: 30).background(Theme.parchment)
    }
}

struct SignalHero: View {
    let network: NetworkRecord?
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi").font(.system(size: 76, weight: .regular)).foregroundStyle(Theme.ink)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(network?.validRSSI.map(String.init) ?? "—").font(.system(size: 56, weight: .semibold)).tracking(-1.5).monospacedDigit()
                Text("dBm").font(.system(size: 17)).foregroundStyle(Theme.muted)
            }
            Text(L(network?.signalLabel ?? "신호 측정 대기")).font(.system(size: 14)).foregroundStyle(Theme.muted)
        }.accessibilityElement(children: .combine)
    }
}
