import Foundation
import CoreWLAN
import CoreLocation
import AppKit
import WiFiCore

struct ScanResult: Sendable {
    let networks: [NetworkRecord]
    let link: LinkSnapshot
    let interfaces: [String]
}

/// All blocking CoreWLAN operations run on one actor, away from the main actor.
actor WiFiScanner {
    private let client = CWWiFiClient.shared()
    func interfaceNames() -> [String] { client.interfaces()?.compactMap(\.interfaceName).sorted() ?? [] }
    private func interface(_ name: String?) throws -> CWInterface {
        if let name {
            guard interfaceNames().contains(name), let selected = client.interface(withName: name) else {
                throw ScanError.message("선택한 네트워크 어댑터를 찾을 수 없습니다. 설정에서 어댑터를 다시 선택하세요.")
            }
            return selected
        }
        guard let interface = client.interface() else {
            throw ScanError.message("Wi-Fi 인터페이스를 찾을 수 없습니다. Wi-Fi 어댑터 연결 상태를 확인하세요.")
        }
        return interface
    }
    func link(name: String?) throws -> LinkSnapshot { snapshot(try interface(name)) }
    func scan(name: String?, includeHidden: Bool) throws -> ScanResult {
        let interface = try interface(name)
        guard interface.powerOn() else { throw ScanError.message("Wi-Fi가 꺼져 있습니다. 시스템 설정에서 Wi-Fi를 켠 후 다시 스캔하세요.") }
        let scanned = try interface.scanForNetworks(withSSID: nil, includeHidden: includeHidden)
        let link = snapshot(interface)
        let time = Date()
        let records = scanned.map { n -> NetworkRecord in
            let channel = n.wlanChannel
            let band: WiFiBand
            switch channel?.channelBand {
            case .band2GHz: band = .two
            case .band5GHz: band = .five
            case .band6GHz: band = .six
            default: band = .unknown
            }
            let width: Int?
            switch channel?.channelWidth {
            case .width20MHz: width = 20
            case .width40MHz: width = 40
            case .width80MHz: width = 80
            case .width160MHz: width = 160
            default: width = nil
            }
            let bssid = n.bssid?.uppercased()
            // Redacted BSSIDs cannot be safely correlated between scans. Never merge them by SSID.
            let identity = bssid ?? "unidentified-\(UUID().uuidString)"
            let modes: [(CWPHYMode, String)] = [(.mode11a,"a"),(.mode11b,"b"),(.mode11g,"g"),(.mode11n,"n"),(.mode11ac,"ac"),(.mode11ax,"ax")]
            let elements = IEParser.parse(n.informationElementData ?? Data()).elements.filter { !$0.truncated }
            var supportedModes = Set(modes.filter { n.supportsPHYMode($0.0) }.map(\.1))
            if elements.contains(where: { $0.elementID == 45 && $0.payload.count >= 26 }) { supportedModes.insert("n") }
            if elements.contains(where: { $0.elementID == 191 && $0.payload.count >= 12 }) { supportedModes.insert("ac") }
            if elements.contains(where: { $0.elementID == 255 && $0.payload.first == 35 && $0.payload.count >= 22 }) { supportedModes.insert("ax") }
            var phy = modes.map(\.1).filter { supportedModes.contains($0) }
            if elements.contains(where: { $0.elementID == 255 && $0.payload.first == 108 }) { phy.append("be (IE)") }
            return NetworkRecord(id: identity, ssid: n.ssid, ssidBytes: n.ssidData, bssid: bssid,
                band: band, channel: channel?.channelNumber ?? 0, widthMHz: width, rssi: n.rssiValue,
                noise: n.noiseMeasurement, security: security(n), phy: phy.joined(separator: "/"),
                country: n.countryCode, beaconInterval: n.beaconInterval, informationElements: n.informationElementData,
                observedAt: time, isConnected: bssid != nil && bssid == link.bssid?.uppercased())
        }
        return ScanResult(networks: NetworkScan.normalized(records), link: link, interfaces: interfaceNames())
    }
    private func snapshot(_ i: CWInterface) -> LinkSnapshot {
        LinkSnapshot(interfaceName: i.interfaceName ?? "Wi-Fi", powerOn: i.powerOn(), ssid: i.ssid(),
                     bssid: i.bssid()?.uppercased(), rssi: i.rssiValue(), noise: i.noiseMeasurement(),
                     transmitRateMbps: i.transmitRate(), transmitPowerMW: i.transmitPower(), channel: i.wlanChannel()?.channelNumber)
    }
    private func security(_ n: CWNetwork) -> String {
        if let advertised = WirelessSecurity.label(from: n.informationElementData) { return advertised }
        // Only query specific modes in the fallback. Mixed modes describe
        // compatibility and do not identify the AP's actual advertised modes.
        let options: [(CWSecurity, String)] = [(.none,"Open"),(.wpa3Personal,"WPA3 Personal"),
            (.wpa3Enterprise,"WPA3 Enterprise"),(.OWE,"OWE"),(.wpa2Personal,"WPA2 Personal"),(.wpa2Enterprise,"WPA2 Enterprise"),
            (.wpaPersonal,"WPA Personal"),(.wpaEnterprise,"WPA Enterprise"),(.dynamicWEP,"Dynamic WEP"),(.WEP,"WEP")]
        return options.first(where: { n.supportsSecurity($0.0) })?.1 ?? "Unknown"
    }
}
enum ScanError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}

@MainActor
final class WiFiStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var networks: [NetworkRecord] = []
    @Published var history: [SignalSample] = []
    @Published var link: LinkSnapshot?
    @Published var interfaces: [String] = []
    @Published var interfaceName: String? = UserDefaults.standard.string(forKey: "selectedAdapter") {
        didSet { UserDefaults.standard.set(interfaceName, forKey: "selectedAdapter") }
    }
    @Published var selectedID: String?
    @Published var isScanning = false
    @Published var isRunning = true
    @Published var isDemo = false
    @Published var error: String?
    @Published var lastScan: Date?
    @Published var scanCount = 0
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var includeHidden = UserDefaults.standard.object(forKey: "includeHidden") as? Bool ?? true {
        didSet { UserDefaults.standard.set(includeHidden, forKey: "includeHidden") }
    }
    @Published var scanInterval: Double = {
        let saved = UserDefaults.standard.double(forKey: "scanInterval")
        return [5, 10, 20, 30].contains(saved) ? saved : 10
    }() {
        didSet { UserDefaults.standard.set(scanInterval, forKey: "scanInterval") }
    }
    @Published var search = ""
    @Published var bandFilter: WiFiBand?
    @Published var securityFilter = "전체"
    @Published var workspace: SavedWorkspace?
    private let scanner = WiFiScanner()
    private let location = CLLocationManager()
    private var timer: Task<Void, Never>?
    private var generation = 0
    private var lastAttempt: Date = .distantPast
    private var tick = 0

    override init() {
        super.init()
        location.delegate = self
        authorization = location.authorizationStatus
        isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        if isDemo { loadDemo() }
    }
    var authorized: Bool { authorization == .authorizedAlways }
    var selected: NetworkRecord? { networks.first { $0.id == selectedID } }
    var filtered: [NetworkRecord] {
        networks.filter { n in
            (bandFilter == nil || n.band == bandFilter) &&
            (securityFilter == "전체" || (securityFilter == "Open" ? n.security == "Open" : n.security != "Open" && n.security != "Unknown")) &&
            (search.isEmpty || [networkTitle(n), n.name, n.bssid ?? "", n.manufacturerName, manufacturerLabel(n.manufacturer), n.security, n.phy, String(n.channel)].contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }
    func start() {
        guard timer == nil else { return }
        timer = Task { [weak self] in
            guard let self else { return }
            self.interfaces = await self.scanner.interfaceNames()
            while !Task.isCancelled {
                if self.isRunning {
                    if self.isDemo {
                        self.updateDemo()
                    } else {
                        let token = self.generation
                        if !self.isScanning {
                            do {
                                let link = try await self.scanner.link(name: self.interfaceName)
                                if token == self.generation && !self.isDemo && self.isRunning { self.updateLink(link) }
                            } catch { if token == self.generation { self.error = error.localizedDescription } }
                        }
                        if self.authorized && Date().timeIntervalSince(self.lastAttempt) >= self.scanInterval {
                            self.scan()
                        }
                    }
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    func requestAccess() { location.requestWhenInUseAuthorization() }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.authorizationChanged() }
    }
    private func authorizationChanged() {
        authorization = location.authorizationStatus
        if authorized && !isDemo && workspace == nil { scan() }
        if !authorized && !isDemo && workspace == nil {
            generation += 1; networks = []; history = []; selectedID = nil; lastScan = nil; link = nil
        }
    }
    func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") { NSWorkspace.shared.open(url) }
    }
    func toggleRunning() {
        guard workspace == nil else { return }
        isRunning.toggle()
        if !isRunning { generation += 1 } else { lastAttempt = .distantPast; if !isDemo { scan() } }
    }
    func changeInterface() {
        guard workspace == nil else { return }
        generation += 1; networks = []; history = []; selectedID = nil; link = nil; lastScan = nil
        lastAttempt = .distantPast; scan()
    }
    func switchMode() {
        workspace = nil
        generation += 1; isDemo.toggle(); error = nil; networks = []; history = []; selectedID = nil
        lastScan = nil; link = nil; scanCount = 0; lastAttempt = .distantPast; isRunning = true
        if isDemo { loadDemo() } else { scan() }
    }
    func scan() {
        guard !isScanning, workspace == nil else { return }
        if isDemo { updateDemo(force: true); return }
        guard authorized else { return }
        isScanning = true; error = nil; lastAttempt = Date()
        let token = generation
        let name = interfaceName
        let hidden = includeHidden
        Task {
            defer { isScanning = false }
            do {
                let result = try await scanner.scan(name: name, includeHidden: hidden)
                guard token == generation, !isDemo else { return }
                networks = result.networks; interfaces = result.interfaces; updateLink(result.link)
                lastScan = Date(); scanCount += 1
                if !networks.contains(where: { $0.id == selectedID }) { selectedID = networks.first(where: \.isConnected)?.id ?? networks.first?.id }
                for n in networks {
                    if let rssi = n.validRSSI { history.append(SignalSample(networkID: n.id, date: n.observedAt, rssi: rssi, noise: n.validNoise)) }
                }
                pruneHistory()
                if networks.isEmpty { error = "스캔 결과가 없습니다. 위치 서비스와 Wi-Fi 상태를 확인하고 다시 시도하세요." }
            } catch { if token == generation { self.error = error.localizedDescription } }
        }
    }
    private func updateLink(_ snapshot: LinkSnapshot) {
        link = snapshot
        for index in networks.indices { networks[index].isConnected = networks[index].bssid != nil && networks[index].bssid == snapshot.bssid }
        if let id = snapshot.bssid, (-127 ..< 0).contains(snapshot.rssi) {
            history.append(SignalSample(networkID: id, date: snapshot.date, rssi: snapshot.rssi,
                                        noise: (-127 ..< 0).contains(snapshot.noise) ? snapshot.noise : nil, source: "CoreWLAN link"))
            pruneHistory()
        }
    }
    func openWorkspace(_ saved: SavedWorkspace) {
        generation += 1
        workspace = saved; isRunning = false; isDemo = saved.isDemo; error = nil
        networks = saved.networks; history = saved.history; link = saved.link
        selectedID = saved.selectedID ?? saved.networks.first?.id
        lastScan = saved.networks.map(\.observedAt).max(); scanCount = 0
    }
    func resumeLive() {
        generation += 1; workspace = nil; isDemo = false; isRunning = true
        networks = []; history = []; selectedID = nil; link = nil; error = nil
        lastScan = nil; scanCount = 0; lastAttempt = .distantPast; scan()
    }
    private func pruneHistory() {
        let cutoff = Date().addingTimeInterval(-900)
        history.removeAll { $0.date < cutoff }
        if history.count > 30000 { history.removeFirst(history.count - 30000) }
    }
    private func loadDemo() {
        networks = DemoData.networks(); selectedID = networks.first?.id
        for second in stride(from: -180, through: 0, by: 10) {
            for (index, n) in networks.enumerated() {
                let variation = Int((sin(Double(second) * 0.055 + Double(index)) * 2.5).rounded())
                history.append(SignalSample(networkID: n.id, date: Date().addingTimeInterval(Double(second)), rssi: n.rssi + variation, noise: n.noise, source: "DEMO"))
            }
        }
        lastScan = Date(); scanCount = 1
        link = LinkSnapshot(interfaceName: "en0 · demo", powerOn: true, ssid: networks[0].ssid, bssid: networks[0].bssid,
                            rssi: -43, noise: -94, transmitRateMbps: 1200, transmitPowerMW: 32, channel: 44)
    }
    private func updateDemo(force: Bool = false) {
        tick += 1
        guard force || Date().timeIntervalSince(lastScan ?? .distantPast) >= scanInterval else { return }
        for i in networks.indices {
            networks[i].rssi = DemoData.baseSignals[i] + Int((sin(Double(tick) * 0.3 + Double(i)) * 3).rounded())
            networks[i].observedAt = Date()
            history.append(SignalSample(networkID: networks[i].id, date: Date(), rssi: networks[i].rssi, noise: networks[i].noise, source: "DEMO"))
        }
        lastScan = Date(); scanCount += 1; pruneHistory()
    }
    func export(json: Bool) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = json ? [.json] : [.commaSeparatedText]
        panel.nameFieldStringValue = "AirScope-\(isDemo ? "demo" : "scan").\(json ? "json" : "csv")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try json ? SessionExport.json(networks: networks, history: history, link: link, demo: isDemo, lastScanAt: lastScan)
                : Data(SessionExport.csv(networks: networks, demo: isDemo).utf8)
            try data.write(to: url, options: .atomic)
        } catch { self.error = "내보내기 실패: \(error.localizedDescription)" }
    }
}
