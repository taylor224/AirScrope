import Foundation

public enum WiFiBand: String, Codable, CaseIterable, Sendable {
    case two = "2.4 GHz", five = "5 GHz", six = "6 GHz", unknown = "Unknown"
    public func frequency(channel: Int) -> Double? {
        guard channel > 0 else { return nil }
        switch self {
        case .two: return channel == 14 ? 2484 : Double(2407 + channel * 5)
        case .five: return Double(5000 + channel * 5)
        case .six: return channel == 2 ? 5935 : Double(5950 + channel * 5)
        case .unknown: return nil
        }
    }
}

public struct NetworkRecord: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var ssid: String?
    public var ssidBytes: Data?
    public var bssid: String?
    public var band: WiFiBand
    public var channel: Int
    public var widthMHz: Int?
    public var rssi: Int
    public var noise: Int
    public var security: String
    public var phy: String
    public var country: String?
    public var beaconInterval: Int
    public var informationElements: Data?
    public var observedAt: Date
    public var isConnected: Bool

    public init(id: String, ssid: String?, ssidBytes: Data? = nil, bssid: String?, band: WiFiBand,
                channel: Int, widthMHz: Int?, rssi: Int, noise: Int, security: String, phy: String,
                country: String? = nil, beaconInterval: Int = 0, informationElements: Data? = nil,
                observedAt: Date = Date(), isConnected: Bool = false) {
        self.id = id; self.ssid = ssid; self.ssidBytes = ssidBytes; self.bssid = bssid
        self.band = band; self.channel = channel; self.widthMHz = widthMHz; self.rssi = rssi
        self.noise = noise; self.security = security; self.phy = phy; self.country = country
        self.beaconInterval = beaconInterval; self.informationElements = informationElements
        self.observedAt = observedAt; self.isConnected = isConnected
    }
    public var name: String {
        if let ssid, !ssid.isEmpty { return ssid }
        if let ssidBytes, ssidBytes.isEmpty { return "Hidden network" }
        return "SSID unavailable"
    }
    public var validRSSI: Int? { (-127 ..< 0).contains(rssi) ? rssi : nil }
    public var validNoise: Int? { (-127 ..< 0).contains(noise) ? noise : nil }
    public var snr: Int? {
        guard let rssi = validRSSI, let noise = validNoise, rssi >= noise else { return nil }
        return rssi - noise
    }
    public var signalLabel: String {
        guard let rssi = validRSSI else { return "측정 없음" }
        return rssi >= -55 ? "매우 좋음" : rssi >= -67 ? "좋음" : rssi >= -75 ? "보통" : "약함"
    }
    public var elements: IEParseResult { IEParser.parse(informationElements ?? Data()) }
    public var channelUtilization: Double? {
        guard let e = elements.elements.first(where: { $0.elementID == 11 && !$0.truncated && $0.payload.count >= 5 }) else { return nil }
        return Double(e.payload[2]) / 255 * 100
    }
    public var stationCount: Int? {
        guard let e = elements.elements.first(where: { $0.elementID == 11 && !$0.truncated && $0.payload.count >= 5 }) else { return nil }
        return Int(e.payload[0]) | Int(e.payload[1]) << 8
    }
    /// A modeled channel envelope, not a measured RF spectrum. Unknown layouts stay unknown.
    public var frequencyRange: ClosedRange<Double>? {
        guard let primary = band.frequency(channel: channel), let width = widthMHz else { return nil }
        if width == 20 { return (primary - 10)...(primary + 10) }
        let ies = elements.elements
        if band == .two, width == 40,
           let ht = ies.first(where: { $0.elementID == 61 && !$0.truncated && $0.payload.count >= 2 }) {
            let secondary = ht.payload[1] & 3
            if secondary == 1 { return (primary - 10)...(primary + 30) }
            if secondary == 3 { return (primary - 30)...(primary + 10) }
            return nil
        }
        if band == .six, channel != 2, [40, 80, 160].contains(width) {
            let first = 1 + ((channel - 1) / (width / 5)) * (width / 5)
            let center = 5950 + Double(first * 5) + Double(width / 2 - 10)
            return (center - Double(width) / 2)...(center + Double(width) / 2)
        }
        if band == .five {
            // VHT 80+80 is noncontiguous; do not render it as a 160 MHz block.
            if let vht = ies.first(where: { $0.elementID == 192 && $0.payload.count >= 3 }),
               vht.payload[0] == 3 || (vht.payload[0] == 1 && vht.payload[2] != 0 && abs(Int(vht.payload[1]) - Int(vht.payload[2])) > 16) { return nil }
            let starts: [Int]
            switch width {
            case 40: starts = [36,44,52,60,100,108,116,124,132,140,149,157,165,173]
            case 80: starts = [36,52,100,116,132,149,165]
            case 160: starts = [36,100,149]
            default: return nil
            }
            if let start = starts.first(where: { channel >= $0 && channel <= $0 + width / 5 - 4 && (channel - $0) % 4 == 0 }) {
                let lower = Double(5000 + start * 5 - 10)
                return lower...(lower + Double(width))
            }
        }
        return nil
    }
}

public struct SignalSample: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public var networkID: String
    public var date: Date
    public var rssi: Int
    public var noise: Int?
    public var source: String
    public init(networkID: String, date: Date, rssi: Int, noise: Int?, source: String = "CoreWLAN scan") {
        self.networkID = networkID; self.date = date; self.rssi = rssi; self.noise = noise; self.source = source
    }
}

public struct LinkSnapshot: Codable, Sendable {
    public var interfaceName: String
    public var powerOn: Bool
    public var ssid: String?
    public var bssid: String?
    public var rssi: Int
    public var noise: Int
    public var transmitRateMbps: Double
    public var transmitPowerMW: Int
    public var channel: Int?
    public var date: Date
    public init(interfaceName: String, powerOn: Bool, ssid: String?, bssid: String?, rssi: Int, noise: Int,
                transmitRateMbps: Double, transmitPowerMW: Int, channel: Int?, date: Date = Date()) {
        self.interfaceName = interfaceName; self.powerOn = powerOn; self.ssid = ssid; self.bssid = bssid
        self.rssi = rssi; self.noise = noise; self.transmitRateMbps = transmitRateMbps
        self.transmitPowerMW = transmitPowerMW; self.channel = channel; self.date = date
    }
}
