import Foundation
import WiFiCore

/// Entirely synthetic SSIDs, locally administered BSSIDs, and IE fixtures.
enum DemoData {
    static let baseSignals = [-43, -56, -61, -68, -72, -77, -80, -66, -59, -74]
    static func networks() -> [NetworkRecord] {
        let specs: [(String, WiFiBand, Int, Int, String)] = [
            ("Demo Main", .five, 44, 80, "WPA3 Personal"),
            ("Demo 2.4 GHz", .two, 6, 20, "WPA2 Personal"),
            ("Demo Access Point 3", .five, 36, 80, "WPA2/WPA3"),
            ("Demo 5 GHz", .five, 149, 80, "WPA2 Personal"),
            ("Demo Guest", .two, 1, 20, "Open"),
            ("Demo Printer", .two, 6, 20, "WPA2 Personal"),
            ("", .two, 11, 20, "WPA2 Personal"),
            ("Demo 6 GHz", .six, 37, 160, "WPA3 Personal"),
            ("Demo Access Point 9", .six, 69, 80, "WPA3 Personal"),
            ("Demo Access Point 10", .five, 48, 40, "WPA2 Personal")]
        return specs.enumerated().map { index, spec in
            let bssid = String(format: "02:00:00:00:01:%02X", index + 1)
            var bytes: [UInt8] = [0, UInt8(spec.0.utf8.count)] + Array(spec.0.utf8)
            bytes += [1, 4, 0x8c, 0x12, 0x98, 0x24, 3, 1, UInt8(spec.2), 7, 3, 0x4b, 0x52, 0x20]
            bytes += [11, 5, UInt8(index + 3), 0, UInt8(index == 0 ? 51 : 80 + index * 10), 0, 0]
            if spec.4 != "Open" {
                bytes += [48, 20, 1, 0, 0, 15, 172, 4, 1, 0, 0, 15, 172, 4, 1, 0, 0, 15, 172, spec.4 == "WPA3 Personal" ? 8 : 2, 0x80, 0]
            }
            bytes += [35, 2, 20, 0, 61, 2, UInt8(spec.2), 0, 221, 4, 0, 80, 242, 2]
            return NetworkRecord(id: bssid, ssid: spec.0, ssidBytes: Data(spec.0.utf8), bssid: bssid,
                band: spec.1, channel: spec.2, widthMHz: spec.3, rssi: baseSignals[index], noise: -94 - index % 3,
                security: spec.4, phy: spec.1 == .two ? "b/g/n/ax" : "a/n/ac/ax", country: "KR", beaconInterval: 100,
                informationElements: Data(bytes), isConnected: index == 0)
        }
    }
}
