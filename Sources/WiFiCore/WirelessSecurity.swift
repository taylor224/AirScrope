import Foundation

/// Classifies the security actually advertised by the AP. CoreWLAN's mixed-mode
/// compatibility queries can also match a single-mode AP, so they are not evidence
/// that the AP advertises both PSK and SAE.
public enum WirelessSecurity {
    public static func label(from data: Data?) -> String? {
        guard let data else { return nil }
        let elements = IEParser.parse(data).elements.filter { !$0.truncated }
        let wpaElement = elements.first { $0.elementID == 221 && $0.payload.starts(with: [0, 80, 242, 1]) }
        let wpa = wpaElement.flatMap { suites(Array($0.payload.dropFirst(4)), oui: [0, 80, 242]) }
        if let rsn = elements.first(where: { $0.elementID == 48 }) {
            guard let rsn = suites(rsn.payload, oui: [0, 15, 172]) else { return "RSN · invalid/unsupported" }
            let akms = Set(rsn.akms)
            let psk = !akms.isDisjoint(with: [2, 4, 6])
            let sae = !akms.isDisjoint(with: [8, 9])
            let enterprise = !akms.isDisjoint(with: [1, 3, 5, 11, 12, 13])
            let base: String
            if psk && sae { base = "WPA2/WPA3" }
            else if sae { base = "WPA3 Personal" }
            else if psk { base = wpa != nil ? "WPA/WPA2" : "WPA2 Personal" }
            else if akms.contains(18) { base = "OWE" }
            else if enterprise {
                if !akms.isDisjoint(with: [11, 12, 13]) { base = "RSN Enterprise · Suite B" }
                else { base = wpa != nil ? "WPA/WPA2 Enterprise" : "WPA2 Enterprise" }
            } else { base = "RSN · other AKM" }
            return base + (rsn.tkip || wpa?.tkip == true ? " · TKIP" : "")
        }
        if let wpa {
            let base = wpa.akms.contains(1) ? "WPA Enterprise" : wpa.akms.contains(2) ? "WPA Personal" : "WPA · other AKM"
            return base + (wpa.tkip ? " · TKIP" : "")
        }
        // Absence of RSN is not proof of an open network (WEP has no RSN IE).
        return nil
    }

    private struct Suites { let akms: [UInt8]; let tkip: Bool }
    private static func suites(_ bytes: [UInt8], oui: [UInt8]) -> Suites? {
        var cursor = 0
        func integer() -> Int? {
            guard cursor + 2 <= bytes.count else { return nil }
            defer { cursor += 2 }
            return Int(bytes[cursor]) | Int(bytes[cursor + 1]) << 8
        }
        func suite() -> UInt8? {
            guard cursor + 4 <= bytes.count else { return nil }
            defer { cursor += 4 }
            // Keep unsupported OUIs distinct from known suite type numbers.
            return bytes[cursor..<cursor + 3].elementsEqual(oui) ? bytes[cursor + 3] : nil
        }
        guard integer() == 1, cursor + 4 <= bytes.count else { return nil }
        var tkip = suite() == 2
        guard let pairwiseCount = integer(), pairwiseCount > 0, pairwiseCount <= (bytes.count - cursor) / 4 else { return nil }
        for _ in 0..<pairwiseCount { if suite() == 2 { tkip = true } }
        guard let akmCount = integer(), akmCount > 0, akmCount <= (bytes.count - cursor) / 4 else { return nil }
        let akms = (0..<akmCount).compactMap { _ in suite() }
        // RSN capabilities are optional, but a trailing single byte is malformed.
        guard bytes.count - cursor != 1 else { return nil }
        return Suites(akms: akms, tkip: tkip)
    }
}
