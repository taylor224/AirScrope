import Foundation

public enum NetworkScan {
    /// CoreWLAN may return multiple cached/hidden variants of one BSSID.
    /// Keep one complete observation; never splice its raw IEs and metrics.
    /// Records without a BSSID cannot safely be correlated and remain separate.
    public static func normalized(_ records: [NetworkRecord]) -> [NetworkRecord] {
        var identified: [String: NetworkRecord] = [:]
        var unidentified: [NetworkRecord] = []
        for var record in records {
            guard let bssid = record.bssid, !bssid.isEmpty else {
                unidentified.append(record)
                continue
            }
            let key = bssid.uppercased()
            record.id = key
            record.bssid = key
            if let existing = identified[key], !preferred(record, over: existing) { continue }
            identified[key] = record
        }
        return (Array(identified.values) + unidentified).sorted {
            let lhs = $0.validRSSI ?? Int.min, rhs = $1.validRSSI ?? Int.min
            return lhs == rhs ? $0.id < $1.id : lhs > rhs
        }
    }

    private static func preferred(_ lhs: NetworkRecord, over rhs: NetworkRecord) -> Bool {
        func hasName(_ n: NetworkRecord) -> Bool {
            !(n.ssid?.isEmpty ?? true) || !(n.ssidBytes?.isEmpty ?? true)
        }
        // A named observation is preferable to a hidden/cache variant. Then
        // prefer usable signal data, richer raw data, and the stronger signal.
        let left = [hasName(lhs) ? 1 : 0, lhs.validRSSI == nil ? 0 : 1,
                    lhs.informationElements?.count ?? 0, lhs.validRSSI ?? Int.min,
                    lhs.validNoise == nil ? 0 : 1]
        let right = [hasName(rhs) ? 1 : 0, rhs.validRSSI == nil ? 0 : 1,
                     rhs.informationElements?.count ?? 0, rhs.validRSSI ?? Int.min,
                     rhs.validNoise == nil ? 0 : 1]
        if left != right { return right.lexicographicallyPrecedes(left) }
        if lhs.observedAt != rhs.observedAt { return lhs.observedAt > rhs.observedAt }
        return (rhs.informationElements ?? Data()).lexicographicallyPrecedes(lhs.informationElements ?? Data())
    }
}
