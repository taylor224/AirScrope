import Foundation

public struct InformationElement: Identifiable, Codable, Sendable, Equatable {
    public var id: Int { offset }
    public var offset: Int
    public var elementID: Int
    public var declaredLength: Int
    public var payload: [UInt8]
    public var truncated: Bool
    public var name: String {
        switch elementID {
        case 0: "SSID"
        case 1: "Supported rates"
        case 3: "DS parameter set"
        case 5: "Traffic indication map"
        case 7: "Country"
        case 11: "BSS load"
        case 32: "Power constraint"
        case 35: "TPC report"
        case 42: "ERP information"
        case 45: "HT capabilities · 802.11n"
        case 48: "RSN · security"
        case 50: "Extended supported rates"
        case 61: "HT operation"
        case 70: "Radio measurement capabilities"
        case 127: "Extended capabilities"
        case 191: "VHT capabilities · 802.11ac"
        case 192: "VHT operation"
        case 201: "Reduced neighbor report"
        case 221: "Vendor specific"
        case 255:
            switch payload.first {
            case 35: "HE capabilities · 802.11ax"
            case 36: "HE operation"
            case 59: "HE 6 GHz capabilities"
            case 106: "EHT operation"
            case 108: "EHT capabilities · 802.11be"
            default: "Extension · \(payload.first.map(String.init) ?? "?")"
            }
        default: "Element \(elementID)"
        }
    }
    public var hex: String { payload.map { String(format: "%02X", $0) }.joined(separator: " ") }
    public var details: [String] {
        if truncated { return ["Truncated: expected \(declaredLength) bytes, received \(payload.count)"] }
        switch elementID {
        case 0: return [payload.isEmpty ? "Hidden SSID" : String(data: Data(payload), encoding: .utf8) ?? "Non-UTF-8 SSID · \(hex)"]
        case 1, 50:
            return [payload.map { String(format: "%g%@", Double($0 & 0x7f) / 2, $0 & 0x80 != 0 ? "*" : "") }.joined(separator: ", ") + " Mbps (* basic)"]
        case 3: return payload.first.map { ["Primary channel: \($0)"] } ?? ["Missing channel"]
        case 7:
            return payload.count >= 3 ? ["Country: \(String(bytes: payload.prefix(3), encoding: .ascii) ?? hex)", "Regulatory triplets: \(max(0, (payload.count - 3) / 3))"] : ["Incomplete country element"]
        case 11:
            guard payload.count >= 5 else { return ["Incomplete BSS load"] }
            return ["Associated stations: \(le16(0))", String(format: "Channel utilization: %.1f%% (%d/255)", Double(payload[2]) / 255 * 100, payload[2]), "Available admission capacity: \(le16(3)) × 32 μs/s"]
        case 32: return payload.first.map { ["Local power constraint: \($0) dB"] } ?? []
        case 35:
            return payload.count >= 2 ? ["Transmit power: \(Int(Int8(bitPattern: payload[0]))) dBm", "Link margin: \(payload[1]) dB"] : ["Incomplete TPC report"]
        case 48: return rsnDetails()
        case 61:
            guard payload.count >= 2 else { return ["Incomplete HT operation"] }
            let offset = payload[1] & 3
            return ["Primary channel: \(payload[0])", "Secondary channel: \(offset == 1 ? "above" : offset == 3 ? "below" : offset == 0 ? "none" : "reserved")"]
        case 192:
            guard payload.count >= 3 else { return ["Incomplete VHT operation"] }
            return ["Channel width code: \(payload[0])", "Center segment 0: \(payload[1])", "Center segment 1: \(payload[2])"]
        case 221:
            guard payload.count >= 3 else { return ["Incomplete vendor OUI"] }
            let oui = payload.prefix(3).map { String(format: "%02X", $0) }.joined(separator: ":")
            return ["OUI: \(oui)"] + (payload.count >= 4 ? ["Vendor type: \(payload[3])"] : [])
        default: return ["\(payload.count) bytes · raw payload preserved"]
        }
    }
    private func le16(_ i: Int) -> Int { Int(payload[i]) | (Int(payload[i + 1]) << 8) }
    private func rsnDetails() -> [String] {
        var cursor = 0
        var result: [String] = []
        func read16() -> Int? {
            guard cursor + 2 <= payload.count else { return nil }
            defer { cursor += 2 }; return le16(cursor)
        }
        func suite(akm: Bool) -> String? {
            guard cursor + 4 <= payload.count else { return nil }
            let bytes = Array(payload[cursor ..< cursor + 4]); cursor += 4
            guard bytes.prefix(3).elementsEqual([0x00,0x0f,0xac]) else { return bytes.map { String(format: "%02X", $0) }.joined(separator: ":") }
            let names: [UInt8:String] = akm
                ? [1:"802.1X",2:"PSK",3:"FT/802.1X",4:"FT/PSK",5:"802.1X SHA-256",6:"PSK SHA-256",8:"SAE",9:"FT/SAE",11:"802.1X Suite B",12:"802.1X Suite B-192",18:"OWE"]
                : [0:"Use group cipher",1:"WEP-40",2:"TKIP",4:"CCMP-128",5:"WEP-104",6:"BIP-CMAC-128",8:"GCMP-128",9:"GCMP-256",10:"CCMP-256",11:"BIP-GMAC-128",12:"BIP-GMAC-256",13:"BIP-CMAC-256"]
            return names[bytes[3]] ?? "00:0F:AC:\(bytes[3])"
        }
        guard let version = read16() else { return ["Incomplete RSN version"] }
        result.append("RSN version: \(version)")
        guard let group = suite(akm: false) else { return result + ["Incomplete group cipher"] }
        result.append("Group cipher: \(group)")
        guard let count = read16(), count <= (payload.count - cursor) / 4 else { return result + ["Invalid pairwise cipher count"] }
        result.append("Pairwise ciphers: " + (0..<count).compactMap { _ in suite(akm: false) }.joined(separator: ", "))
        guard let akms = read16(), akms <= (payload.count - cursor) / 4 else { return result + ["Invalid AKM count"] }
        result.append("Authentication: " + (0..<akms).compactMap { _ in suite(akm: true) }.joined(separator: ", "))
        if cursor == payload.count { return result }
        guard let caps = read16() else { return result + ["Incomplete RSN capabilities"] }
        result.append(String(format: "RSN capabilities: 0x%04X", caps))
        result.append("Management frame protection: \(caps & 0x40 != 0 ? "required" : caps & 0x80 != 0 ? "capable" : "not advertised")")
        return result
    }
}

public struct IEParseResult: Sendable {
    public var elements: [InformationElement]
    public var warnings: [String]
}
public enum IEParser {
    public static func parse(_ data: Data) -> IEParseResult {
        let bytes = Array(data)
        var offset = 0
        var elements: [InformationElement] = []
        var warnings: [String] = []
        while offset < bytes.count {
            guard offset + 2 <= bytes.count else { warnings.append("Incomplete IE header at byte \(offset)"); break }
            let length = Int(bytes[offset + 1])
            let end = min(bytes.count, offset + 2 + length)
            let truncated = end < offset + 2 + length
            elements.append(InformationElement(offset: offset, elementID: Int(bytes[offset]), declaredLength: length,
                                               payload: Array(bytes[(offset + 2)..<end]), truncated: truncated))
            if truncated { warnings.append("Truncated IE \(bytes[offset]) at byte \(offset)"); break }
            offset = end
        }
        return IEParseResult(elements: elements, warnings: warnings)
    }
    public static func hexDump(_ data: Data) -> String {
        let bytes = Array(data)
        return stride(from: 0, to: bytes.count, by: 16).map { offset in
            let row = bytes[offset..<min(offset + 16, bytes.count)]
            let hex = row.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = row.map { (32...126).contains($0) ? String(UnicodeScalar($0)) : "." }.joined()
            return String(format: "%04X  ", offset) + hex.padding(toLength: 47, withPad: " ", startingAt: 0) + "  " + ascii
        }.joined(separator: "\n")
    }
}
