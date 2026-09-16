import SwiftUI
import WiFiCore

struct InsightsView: View {
    let network: NetworkRecord?
    let networks: [NetworkRecord]
    let history: [SignalSample]
    var body: some View {
        if let network {
            let findings = SignalAnalysis.findings(for: network, among: networks, history: history)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 20)], spacing: 20) {
                ForEach(findings) { finding in
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: finding.severity == .good ? "checkmark.circle" : finding.severity == .warning ? "exclamationmark.triangle" : "info.circle")
                            .font(.system(size: 24, weight: .light)).foregroundStyle(Theme.secondary)
                        Text(findingText(finding).title).font(.system(size: 17, weight: .semibold)).tracking(-0.3)
                        Text(findingText(finding).detail).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }.padding(24).frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading).utilityCard()
                }
            }
        } else {
            EmptyState(symbol: "waveform.path", title: L("신호 분석 대기"), detail: "네트워크를 선택하면 신호 세기, 채널 중첩과 보안 정보를 분석합니다.")
        }
    }
}

struct RawDataView: View {
    let network: NetworkRecord?
    @State private var query = ""
    @State private var hexMode = false
    @State private var copied = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField(L("IE 이름, ID, 해석 내용 검색"), text: $query).textFieldStyle(.plain)
                }.font(.system(size: 14)).padding(.horizontal, 16).frame(width: 300, height: 40)
                    .background(Theme.parchment, in: Capsule())
                Spacer()
                Picker(L("보기 방식"), selection: $hexMode) {
                    Text(L("해석된 IE")).tag(false); Text(L("전체 Hex")).tag(true)
                }.pickerStyle(.segmented).frame(width: 190)
                Button {
                    if let data = network?.informationElements {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(IEParser.hexDump(data), forType: .string)
                        copied = true
                    }
                } label: { Label(L(copied ? "복사됨" : "Hex 복사"), systemImage: copied ? "checkmark" : "doc.on.doc") }
                    .buttonStyle(LinkButton()).font(.system(size: 14)).disabled(network?.informationElements == nil)
            }.padding(20)
            Theme.line.frame(height: 1)
            if let data = network?.informationElements, !data.isEmpty {
                let parsed = IEParser.parse(data)
                let filtered = parsed.elements.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || String($0.elementID).contains(query) || $0.details.joined().localizedCaseInsensitiveContains(query) }
                if !hexMode {
                    HStack(spacing: 20) {
                        Text("ID").frame(width: 38, alignment: .leading)
                        Text(L("길이")).frame(width: 56, alignment: .leading)
                        Text("Information Element").frame(width: 250, alignment: .leading)
                        Text(L("해석")).frame(maxWidth: .infinity, alignment: .leading)
                    }.font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted).padding(.leading, 44).padding(.trailing, 24).padding(.vertical, 12).background(Theme.pearl)
                }
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(parsed.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.system(size: 14)).padding(16) }
                        if hexMode {
                            Text(IEParser.hexDump(data)).font(.system(size: 14, design: .monospaced)).foregroundStyle(Theme.secondary)
                                .textSelection(.enabled).lineSpacing(9).padding(24)
                        } else {
                            ForEach(filtered) { element in
                                DisclosureGroup {
                                    VStack(alignment: .leading, spacing: 10) {
                                        ForEach(Array(element.details.enumerated()), id: \.offset) { _, detail in
                                            Text(detail).font(.system(size: 14)).textSelection(.enabled)
                                        }
                                        Text(element.hex.isEmpty ? "(empty payload)" : element.hex)
                                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.secondary).textSelection(.enabled)
                                            .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Theme.parchment, in: RoundedRectangle(cornerRadius: 8))
                                        Text("Offset \(element.offset) · \(element.payload.count) bytes")
                                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                                    }.padding(.vertical, 16).padding(.leading, 18)
                                } label: {
                                    HStack(spacing: 20) {
                                        Text(String(format: "%03d", element.elementID)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted).frame(width: 38, alignment: .leading)
                                        Text("\(element.declaredLength) B").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted).frame(width: 56, alignment: .leading)
                                        Text(element.name).font(.system(size: 14, weight: .semibold)).frame(width: 250, alignment: .leading)
                                        Text(element.details.first ?? L("미해석 IE")).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                    }.padding(.vertical, 14)
                                }.padding(.horizontal, 24)
                                Theme.softLine.frame(height: 1)
                            }
                            if filtered.isEmpty { Text(L("일치하는 Information Element가 없습니다.")).font(.system(size: 17)).foregroundStyle(Theme.muted).padding(32) }
                        }
                    }.frame(minWidth: 880, maxWidth: .infinity, alignment: .leading)
                }
            } else {
                EmptyState(symbol: "curlybraces", title: network == nil ? "네트워크를 선택하세요" : "원시 데이터가 없습니다", detail: "macOS가 제공한 Information Element만 표시합니다.")
            }
        }.onChange(of: network?.id) { _, _ in copied = false }
    }
}

struct NetworkDetailsView: View {
    let network: NetworkRecord?
    var isDemo = false
    var body: some View {
        ScrollView {
            if let n = network {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(networkTitle(n)).font(.system(size: 34, weight: .semibold)).tracking(-0.37).textSelection(.enabled)
                        Text(manufacturerLabel(n.manufacturer)).font(.system(size: 17)).foregroundStyle(Theme.muted).textSelection(.enabled)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 24) {
                        row("BSSID", n.bssid ?? "제공되지 않음")
                        row("대역 · 채널 · 폭", "\(n.band.rawValue) · \(n.channel) · \(n.widthMHz.map { "\($0) MHz" } ?? "폭 미확인")")
                        row("제조사 · IEEE 등록기관", manufacturerLabel(n.manufacturer))
                        row("주소 할당", n.manufacturer.prefix != nil ? n.manufacturer.assignmentDescription : manufacturerLabel(n.manufacturer))
                        row("원본 SSID bytes", n.ssidBytes?.map { String(format: "%02X", $0) }.joined(separator: " ") ?? "제공되지 않음")
                        row("국가", n.country ?? "제공되지 않음")
                        row("Beacon interval", n.beaconInterval > 0 ? "\(n.beaconInterval) ms" : "제공되지 않음")
                        row("PHY modes", n.phy.isEmpty ? "제공되지 않음" : n.phy)
                        row("보안", n.security)
                        row("보안 판별 근거", isDemo ? L("샘플 데이터") : WirelessSecurity.label(from: n.informationElements) != nil ? "원시 RSN / WPA IE" : L("보안 판별 근거"))
                        row("원본 RSSI / noise", "\(n.rssi) / \(n.noise) dBm")
                        row("AP 보고 접속 기기 수", n.stationCount.map(String.init) ?? "BSS Load IE 없음")
                        row("Primary 주파수", n.band.frequency(channel: n.channel).map { String(format: "%.0f MHz", $0) } ?? "미확인")
                        row("관측 시각", n.observedAt.formatted(date: .omitted, time: .standard))
                    }.padding(24).utilityCard()
                    Text(L("제조사 안내 {0}", ManufacturerDirectory.shared.updatedAt))
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                }.padding(24)
            } else { EmptyState(symbol: "wifi", title: "네트워크를 선택하세요", detail: L("네트워크를 선택하세요")) }
        }
    }
    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(title)).font(.system(size: 12)).foregroundStyle(Theme.muted)
            Text(L(value)).font(.system(size: 14)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
