import Testing
import Foundation
@testable import WiFiCore

// All SSIDs, complete MAC addresses, measurements, and bytes below are synthetic.
// The Cisco prefix test uses a public IEEE allocation with a fabricated suffix.

private func network(_ id: String = "A", band: WiFiBand = .five, channel: Int = 44, width: Int? = 80,
                     rssi: Int = -50, noise: Int = -95, ie: Data? = nil) -> NetworkRecord {
    NetworkRecord(id: id, ssid: "Test", bssid: id, band: band, channel: channel, widthMHz: width,
                  rssi: rssi, noise: noise, security: "WPA3 Personal", phy: "ax", informationElements: ie)
}

@Test func malformedTLVPreservesAvailableBytes() {
    let data = Data([0, 0, 11, 5, 1, 0])
    let result = IEParser.parse(data)
    #expect(result.elements.count == 2)
    #expect(result.elements[0].details == ["Hidden SSID"])
    #expect(result.elements[1].truncated)
    #expect(result.elements[1].payload == [1, 0])
    #expect(result.warnings.count == 1)
    #expect(IEParser.parse(Data([0])).warnings.count == 1)
}
@Test func repeatedElementsHaveUniqueOffsets() {
    let result = IEParser.parse(Data([221, 3, 1, 2, 3, 221, 4, 4, 5, 6, 7]))
    #expect(result.elements.map(\.id) == [0, 5])
    #expect(result.elements[1].details == ["OUI: 04:05:06", "Vendor type: 7"])
}
@Test func bssLoadUsesLittleEndianAnd255Scale() {
    let n = network(ie: Data([11, 5, 0x34, 0x12, 255, 0x20, 0]))
    #expect(n.stationCount == 4660)
    #expect(n.channelUtilization == 100)
    #expect(n.elements.elements[0].details.last == "Available admission capacity: 32 × 32 μs/s")
    #expect(network(ie: Data([11, 5, 1, 0, 255])).channelUtilization == nil)
}
@Test func rsnDecodesSAEAndMFPCapabilities() {
    let bytes: [UInt8] = [48, 20, 1, 0, 0, 15, 172, 4, 1, 0, 0, 15, 172, 4, 1, 0, 0, 15, 172, 8, 0xc0, 0]
    let details = IEParser.parse(Data(bytes)).elements[0].details
    #expect(details.contains("Authentication: SAE"))
    #expect(details.contains("Pairwise ciphers: CCMP-128"))
    #expect(details.contains("Management frame protection: required"))
}
@Test func maliciousRSNCountDoesNotOverread() {
    let bytes: [UInt8] = [48, 8, 1, 0, 0, 15, 172, 4, 255, 255]
    #expect(IEParser.parse(Data(bytes)).elements[0].details.last == "Invalid pairwise cipher count")
}
@Test func allTruncationsAndRandomInputsRemainBounded() {
    let valid: [UInt8] = [0,4,84,101,115,116,48,20,1,0,0,15,172,4,1,0,0,15,172,4,1,0,0,15,172,8,0x80,0]
    for length in 0...valid.count {
        let result = IEParser.parse(Data(valid.prefix(length)))
        for e in result.elements { #expect(e.payload.count <= e.declaredLength); _ = e.details; _ = e.name }
    }
    var seed: UInt64 = 42
    for length in 0..<512 {
        let bytes: [UInt8] = (0..<length).map { _ in seed = seed &* 6364136223846793005 &+ 1; return UInt8(truncatingIfNeeded: seed >> 32) }
        for e in IEParser.parse(Data(bytes)).elements { #expect(e.offset + 2 + e.payload.count <= length); _ = e.details }
        _ = WirelessSecurity.label(from: Data(bytes))
    }
}
@Test func missingMetricsNeverBecomeExcellentSignal() {
    #expect(network(rssi: 0, noise: 0).validRSSI == nil)
    #expect(network(rssi: 0, noise: 0).snr == nil)
    #expect(network(noise: 0).snr == nil)
    #expect(network(rssi: -90, noise: -50).snr == nil)
    #expect(network().snr == 45)
}
@Test func channelGeometryAndBandIsolation() {
    #expect(network().frequencyRange == 5170...5250)
    #expect(network(band: .six, channel: 37, width: 160).frequencyRange == 6105...6265)
    #expect(WiFiBand.two.frequency(channel: 14) == 2484)
    #expect(WiFiBand.six.frequency(channel: 2) == 5935)
    #expect(SignalAnalysis.overlap(network(), network("B", channel: 36)))
    #expect(!SignalAnalysis.overlap(network(), network("B", band: .six, channel: 37, width: 160)))
    #expect(!SignalAnalysis.overlap(network(), network("B", channel: 52)))
    #expect(network(band: .two, channel: 6, width: 40).frequencyRange == nil)
    #expect(network(width: nil).frequencyRange == nil)
    #expect(network(width: 160, ie: Data([192,3,1,42,106])).frequencyRange == nil)
}
@Test func htSecondaryChannelControls40MHzCenter() {
    #expect(network(band: .two, channel: 6, width: 40, ie: Data([61,2,6,1])).frequencyRange == 2427...2467)
    #expect(network(band: .two, channel: 6, width: 40, ie: Data([61,2,6,3])).frequencyRange == 2407...2447)
}
@Test func exportPreservesBytesAndQuotesCSV() throws {
    var n = network(ie: Data([0,0,255]))
    n.ssid = "=HYPERLINK(\"example\")\nSSID"; n.ssidBytes = Data([0,255])
    let csv = SessionExport.csv(networks: [n], demo: true)
    #expect(csv.contains("\"'=HYPERLINK(\"\"example\"\")\nSSID\""))
    #expect(csv.contains("\"-50\""))
    let json = try SessionExport.json(networks: [n], history: [], link: nil, demo: true)
    let object = try #require(JSONSerialization.jsonObject(with: json) as? [String:Any])
    #expect((object["source"] as? String)?.contains("DEMO") == true)
    let entries = try #require(object["networks"] as? [[String:Any]])
    #expect(entries[0]["ssid"] as? String == n.ssid)
    #expect(Data(base64Encoded: entries[0]["informationElements"] as! String) == n.informationElements)
}
@Test func unknownAPsAreNotInventedAsHidden() {
    var n = network(); n.ssid = nil; n.ssidBytes = nil
    #expect(n.name == "SSID unavailable")
    n.ssidBytes = Data()
    #expect(n.name == "Hidden network")
}
@Test func mixedLegacySecurityIsFlagged() {
    var n = network(); n.security = "WPA/WPA2"
    #expect(SignalAnalysis.findings(for: n, among: [n], history: []).contains { $0.id == "security" && $0.severity == .warning })
    n.security = "WPA2/WPA3"
    #expect(!SignalAnalysis.findings(for: n, among: [n], history: []).contains { $0.id == "security" })
}

private func rsnIE(akms: [UInt8], cipher: UInt8 = 4) -> Data {
    var payload: [UInt8] = [1,0,0,15,172,cipher,1,0,0,15,172,cipher,UInt8(akms.count),0]
    for akm in akms { payload += [0,15,172,akm] }
    payload += [0xc0,0]
    return Data([48,UInt8(payload.count)] + payload)
}
@Test func advertisedAKMsDistinguishWPA2WPA3AndTransition() {
    #expect(WirelessSecurity.label(from: rsnIE(akms: [2])) == "WPA2 Personal")
    #expect(WirelessSecurity.label(from: rsnIE(akms: [8,9])) == "WPA3 Personal")
    #expect(WirelessSecurity.label(from: rsnIE(akms: [2,8])) == "WPA2/WPA3")
    #expect(WirelessSecurity.label(from: rsnIE(akms: [1])) == "WPA2 Enterprise")
    #expect(WirelessSecurity.label(from: rsnIE(akms: [18])) == "OWE")
    #expect(WirelessSecurity.label(from: rsnIE(akms: [99])) == "RSN · other AKM")
}
@Test func legacyWPARequiresActualWPAElement() {
    let wpa = Data([221,22,0,80,242,1,1,0,0,80,242,2,1,0,0,80,242,2,1,0,0,80,242,2])
    #expect(WirelessSecurity.label(from: wpa) == "WPA Personal · TKIP")
    #expect(WirelessSecurity.label(from: wpa + rsnIE(akms: [2])) == "WPA/WPA2 · TKIP")
    // WMM shares WPA's OUI; vendor type 2 must not be treated as WPA type 1.
    let wmm = Data([221,4,0,80,242,2])
    #expect(WirelessSecurity.label(from: wmm + rsnIE(akms: [2])) == "WPA2 Personal")
    #expect(WirelessSecurity.label(from: rsnIE(akms: [2], cipher: 2)) == "WPA2 Personal · TKIP")
}
@Test func incompleteSecurityNeverImpliesOpen() {
    #expect(WirelessSecurity.label(from: nil) == nil)
    #expect(WirelessSecurity.label(from: Data([0,0])) == nil)
    #expect(WirelessSecurity.label(from: Data([48,8,1,0,0,15,172,4,255,255])) == "RSN · invalid/unsupported")
    var foreignOUI = Array(rsnIE(akms: [2])); foreignOUI[16] = 1
    #expect(WirelessSecurity.label(from: Data(foreignOUI)) == "RSN · other AKM")
    let valid = rsnIE(akms: [8,9])
    for length in 0..<valid.count { #expect(WirelessSecurity.label(from: Data(valid.prefix(length))) == nil) }
}

@Test func duplicateBSSIDsKeepOneCoherentObservation() throws {
    let named = network("AA:BB:CC:DD:EE:FF", rssi: -65, ie: rsnIE(akms: [8]))
    var hidden = network("aa:bb:cc:dd:ee:ff", rssi: -40, ie: rsnIE(akms: [2,8]))
    hidden.ssid = nil; hidden.ssidBytes = Data()
    let result = NetworkScan.normalized([hidden, named])
    #expect(result.count == 1)
    #expect(try #require(result.first) == named)
    #expect(NetworkScan.normalized([named, hidden]) == result)
    // Repeated input does not duplicate history or inflate channel counts.
    #expect(NetworkScan.normalized(result + result) == result)
}

@Test func sameSSIDAndUnidentifiedNetworksStaySeparate() {
    let first = network("A", rssi: -65)
    let second = network("B", rssi: -40)
    var redacted = network("unidentified-1", rssi: 0); redacted.bssid = nil
    var otherRedacted = redacted; otherRedacted.id = "unidentified-2"
    let result = NetworkScan.normalized([first, redacted, second, otherRedacted])
    #expect(result.map(\.id) == ["B", "A", "unidentified-1", "unidentified-2"])
}

@Test func duplicatePreferenceKeepsUsefulRawDataAndValidSignal() {
    let rich = network("A", rssi: -65, ie: rsnIE(akms: [8]))
    let empty = network("A", rssi: -40)
    var invalid = rich; invalid.rssi = 0
    #expect(NetworkScan.normalized([empty, rich, invalid]) == [rich])
    var stronger = rich; stronger.rssi = -55
    #expect(NetworkScan.normalized([rich, stronger]) == [stronger])
}

@Test func manufacturerUsesLongestAssignedPrefix() {
    let directory = ManufacturerDirectory(entries: [
        "001122": .init(organization: "Large", registry: "MA-L"),
        "0011223": .init(organization: "Medium", registry: "MA-M"),
        "001122334": .init(organization: "Small", registry: "MA-S")
    ])
    #expect(directory.lookup("00:11:22:33:44:55").organization == "Small")
    #expect(directory.lookup("00-11-22-3a-bb-cc").organization == "Medium")
    #expect(directory.lookup("001122FFFFFF").organization == "Large")
    #expect(directory.lookup("001122334455").assignmentDescription == "MA-S · 001122334 / 36 bits")
}
@Test func localAndInvalidAddressesNeverInventManufacturers() {
    let directory = ManufacturerDirectory(entries: ["021122": .init(organization: "Must not match", registry: "MA-L")])
    #expect(directory.lookup("02:11:22:33:44:55").kind == .local)
    #expect(directory.lookup("FF:FF:FF:FF:FF:FF").kind == .multicast)
    for address: String? in [nil, "", "0011", "00:11:22:33:44:GG", "00:11:22:334:4:55", "00:00:00:00:00:00"] {
        #expect(directory.lookup(address).kind == .unavailable)
    }
    #expect(directory.lookup("00:11:22:33:44:55").kind == .unknown)
    #expect(ManufacturerDirectory(entries: [:]).lookup("00:11:22:33:44:55").kind == .databaseUnavailable)
}
@Test func bundledIEEERegistryLoadsAndExportsAttribution() throws {
    let result = ManufacturerDirectory.shared.lookup("00:00:0C:00:00:01")
    #expect(result.kind == .registered)
    #expect(result.organization?.localizedCaseInsensitiveContains("Cisco") == true)
    #expect(result.registry == "MA-L")
    let n = network("00:00:0C:00:00:01")
    let data = try SessionExport.json(networks: [n], history: [], link: nil, demo: false)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["schemaVersion"] as? Int == 2)
    let manufacturers = try #require(object["manufacturers"] as? [String: [String: Any]])
    #expect(manufacturers[n.id]?["organization"] as? String == result.organization)
    #expect(SessionExport.csv(networks: [n], demo: false).contains("manufacturer_registry"))
}

@Test func workspaceSurvivesRepositoryRecreationWithOriginalBytes() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AirScope-test-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    var n = network("00:00:0C:00:00:01", ie: Data([0,0,48,1,255])); n.observedAt = date
    let sample = SignalSample(networkID: n.id, date: date, rssi: -50, noise: -95)
    let saved = SavedWorkspace(name: "Office / 사무실 / 办公室", savedAt: date, isDemo: false,
                               networks: [n], history: [sample], link: nil, selectedID: n.id)
    try await WorkspaceRepository(directory: directory).save(saved)
    let reopenedRepository = WorkspaceRepository(directory: directory)
    let summaries = try await reopenedRepository.list()
    #expect(summaries.count == 1)
    #expect(summaries.first?.name == saved.name)
    let restored = try await reopenedRepository.load(saved.id)
    #expect(restored.networks == [n])
    #expect(restored.history.first?.date == date)
    #expect(restored.history.first?.id == sample.id)
    #expect(restored.selectedID == n.id)
    #expect(restored.isDemo == false)
}
