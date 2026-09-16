import Foundation

public struct ManufacturerInfo: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case registered, local, multicast, unknown, unavailable, databaseUnavailable }
    public let kind: Kind
    public let organization: String?
    public let prefix: String?
    public let registry: String?
    public var label: String {
        switch kind {
        case .registered: organization ?? "등록기관 미확인"
        case .local: "로컬 관리 주소"
        case .multicast: "그룹 주소"
        case .unknown: "등록기관 미확인"
        case .unavailable: "주소 미제공"
        case .databaseUnavailable: "등록 데이터 없음"
        }
    }
    public var assignmentDescription: String {
        if let prefix, let registry { return "\(registry) · \(prefix) / \(prefix.count * 4) bits" }
        switch kind {
        case .local: return "로컬 관리 비트 설정 · 제조사 추정 안 함"
        case .multicast: return "개별 기기 주소가 아님"
        default: return label
        }
    }
}

public struct ManufacturerDirectory: Sendable {
    public struct Entry: Codable, Sendable {
        public let organization: String
        public let registry: String
        public init(organization: String, registry: String) { self.organization = organization; self.registry = registry }
    }
    private struct Registry: Decodable {
        let updatedAt: String
        let entries: [String: Entry]
    }
    public let updatedAt: String
    private let entries: [String: Entry]
    public init(entries: [String: Entry], updatedAt: String = "test") { self.entries = entries; self.updatedAt = updatedAt }
    public static let shared: ManufacturerDirectory = {
        let url = Bundle.main.url(forResource: "manufacturers", withExtension: "json")
            ?? Bundle.module.url(forResource: "manufacturers", withExtension: "json")
        guard let url,
              let data = try? Data(contentsOf: url), let registry = try? JSONDecoder().decode(Registry.self, from: data) else {
            return ManufacturerDirectory(entries: [:], updatedAt: "unavailable")
        }
        return ManufacturerDirectory(entries: registry.entries, updatedAt: registry.updatedAt)
    }()
    public func lookup(_ bssid: String?) -> ManufacturerInfo {
        func result(_ kind: ManufacturerInfo.Kind) -> ManufacturerInfo { ManufacturerInfo(kind: kind, organization: nil, prefix: nil, registry: nil) }
        guard let bssid else { return result(.unavailable) }
        let compact: String
        if bssid.contains(":") || bssid.contains("-") {
            let separator: Character = bssid.contains(":") ? ":" : "-"
            let parts = bssid.split(separator: separator, omittingEmptySubsequences: false)
            guard parts.count == 6, parts.allSatisfy({ $0.count == 2 }) else { return result(.unavailable) }
            compact = parts.joined().uppercased()
        } else { compact = bssid.uppercased() }
        guard compact.utf8.count == 12, compact.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }),
              let first = UInt8(compact.prefix(2), radix: 16), compact != "000000000000" else { return result(.unavailable) }
        if first & 1 != 0 { return result(.multicast) }
        if first & 2 != 0 { return result(.local) }
        guard !entries.isEmpty else { return result(.databaseUnavailable) }
        // MA-S / IAB (36 bits) and MA-M (28 bits) override their parent OUI.
        for length in [9, 7, 6] {
            let prefix = String(compact.prefix(length))
            if let entry = entries[prefix] {
                return ManufacturerInfo(kind: .registered, organization: entry.organization, prefix: prefix, registry: entry.registry)
            }
        }
        return result(.unknown)
    }
}

extension NetworkRecord {
    public var manufacturer: ManufacturerInfo { ManufacturerDirectory.shared.lookup(bssid) }
    public var manufacturerName: String { manufacturer.label }
}
