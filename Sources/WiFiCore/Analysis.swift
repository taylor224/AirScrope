import Foundation

public struct Finding: Identifiable, Sendable {
    public let id: String
    public let severity: Severity
    public let title: String
    public let detail: String
    public var values: [String] = []
    public enum Severity: String, Sendable { case good, info, warning }
}
public enum SignalAnalysis {
    public static func overlap(_ a: NetworkRecord, _ b: NetworkRecord) -> Bool {
        guard a.id != b.id, a.band == b.band, let ar = a.frequencyRange, let br = b.frequencyRange else { return false }
        return min(ar.upperBound, br.upperBound) > max(ar.lowerBound, br.lowerBound)
    }
    public static func findings(for network: NetworkRecord, among networks: [NetworkRecord], history: [SignalSample]) -> [Finding] {
        var findings: [Finding] = []
        if let rssi = network.validRSSI {
            findings.append(Finding(id: "signal", severity: rssi < -70 ? .warning : .good,
                title: rssi < -70 ? "신호가 약합니다" : "안정적인 신호 세기",
                detail: "RSSI \(rssi) dBm. " + (rssi < -70 ? "AP에 가까운 위치에서 다시 측정해 보세요." : "현재 위치에서 수신 신호가 양호합니다.") + " 신호 평가는 경험적 기준입니다.", values: [String(rssi)]))
        }
        if let snr = network.snr {
            findings.append(Finding(id: "snr", severity: snr < 20 ? .warning : .good,
                title: snr < 20 ? "신호와 노이즈 간격이 작습니다" : "충분한 신호 대 잡음비",
                detail: "SNR \(snr) dB = RSSI − noise. 20 dB 미만은 이 앱의 주의 기준입니다.", values: [String(snr)]))
        }
        let neighbors = networks.filter { overlap(network, $0) && ($0.validRSSI ?? -127) > -85 }
        if !neighbors.isEmpty {
            findings.append(Finding(id: "overlap", severity: neighbors.count >= 3 ? .warning : .info,
                title: "주파수가 겹치는 AP \(neighbors.count)개",
                detail: "−85 dBm보다 강한 AP의 채널 범위가 겹칩니다. AP 개수는 실제 트래픽 혼잡도나 간섭 측정값이 아닙니다.", values: [String(neighbors.count)]))
        }
        if let utilization = network.channelUtilization {
            findings.append(Finding(id: "load", severity: utilization >= 70 ? .warning : .info,
                title: String(format: "AP 보고 채널 사용률 %.0f%%", utilization),
                detail: "BSS Load IE의 원시 값 / 255. Mac이 측정한 사용률이 아니며 AP가 보고한 값입니다.", values: [String(format: "%.0f", utilization)]))
        }
        if network.security == "Open" || network.security.contains("WEP") || network.security.contains("TKIP") || network.security.hasPrefix("WPA/") || ["WPA Personal", "WPA Enterprise"].contains(network.security) {
            findings.append(Finding(id: "security", severity: .warning, title: "보안 설정을 확인하세요", detail: "\(network.security)로 광고되고 있습니다. 관리하는 AP라면 WPA2-AES 또는 WPA3 설정을 확인하세요.", values: [network.security]))
        }
        let recent = history.filter { $0.networkID == network.id && $0.source != "CoreWLAN link" }.suffix(12).map { Double($0.rssi) }
        if recent.count >= 5 {
            let mean = recent.reduce(0, +) / Double(recent.count)
            let sd = sqrt(recent.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recent.count))
            if sd > 5 { findings.append(Finding(id: "variation", severity: .warning, title: "신호 변동이 큽니다", detail: String(format: "최근 %d회 스캔의 RSSI 표준편차 %.1f dB. 위치 변화나 무선 환경 변화를 확인하세요.", recent.count, sd), values: [String(recent.count), String(format: "%.1f", sd)])) }
        }
        if network.informationElements == nil {
            findings.append(Finding(id: "raw", severity: .info, title: "원시 IE가 제공되지 않았습니다", detail: "이 스캔에서 macOS가 Information Element 바이트를 반환하지 않았습니다. 값을 추정해 채우지 않습니다."))
        }
        return findings
    }
}

public enum SessionExport {
    private struct Session: Codable {
        let schemaVersion: Int
        let source: String
        let exportedAt: Date
        let lastScanAt: Date?
        let networks: [NetworkRecord]
        let history: [SignalSample]
        let link: LinkSnapshot?
        let manufacturers: [String: ManufacturerInfo]
        let manufacturerDataUpdatedAt: String
    }
    public static func json(networks: [NetworkRecord], history: [SignalSample], link: LinkSnapshot?, demo: Bool, lastScanAt: Date? = nil) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manufacturers = Dictionary(networks.map { ($0.id, $0.manufacturer) }, uniquingKeysWith: { first, _ in first })
        return try encoder.encode(Session(schemaVersion: 2, source: demo ? "DEMO — synthetic data" : "Apple CoreWLAN", exportedAt: Date(), lastScanAt: lastScanAt, networks: networks, history: history, link: link,
                                          manufacturers: manufacturers, manufacturerDataUpdatedAt: ManufacturerDirectory.shared.updatedAt))
    }
    public static func csv(networks: [NetworkRecord], demo: Bool) -> String {
        let formatter = ISO8601DateFormatter()
        let header = "source,observed_at,ssid,bssid,band,channel,width_mhz,rssi_dbm,noise_dbm,snr_db,security,phy,country,beacon_interval_ms,ssid_hex,ie_hex,manufacturer,manufacturer_registry,manufacturer_prefix"
        let rows: [String] = networks.map { n in
            var cells: [String] = [demo ? "DEMO" : "CoreWLAN", formatter.string(from: n.observedAt), n.ssid ?? "", n.bssid ?? "", n.band.rawValue]
            cells += [String(n.channel), n.widthMHz.map { String($0) } ?? "", String(n.rssi), String(n.noise), n.snr.map { String($0) } ?? ""]
            cells += [n.security, n.phy, n.country ?? "", String(n.beaconInterval)]
            cells.append((n.ssidBytes ?? Data()).map { String(format: "%02X", $0) }.joined())
            cells.append((n.informationElements ?? Data()).map { String(format: "%02X", $0) }.joined())
            cells += [n.manufacturerName, n.manufacturer.registry ?? "", n.manufacturer.prefix ?? ""]
            return cells.map(csvCell).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\r\n") + "\r\n"
    }
    private static func csvCell(_ value: String) -> String {
        // Keep nearby, untrusted SSIDs from becoming spreadsheet formulas. JSON preserves exact strings.
        let protected = ["=", "+", "-", "@", "\t", "\r", "\n"].contains(where: { value.hasPrefix($0) }) && Double(value) == nil ? "'" + value : value
        return "\"" + protected.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
