import Foundation

public struct SavedWorkspace: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public let savedAt: Date
    public let isDemo: Bool
    public let networks: [NetworkRecord]
    public let history: [SignalSample]
    public let link: LinkSnapshot?
    public let selectedID: String?
    public init(id: UUID = UUID(), name: String, savedAt: Date = Date(), isDemo: Bool,
                networks: [NetworkRecord], history: [SignalSample], link: LinkSnapshot?, selectedID: String?) {
        self.id = id; self.name = name; self.savedAt = savedAt; self.isDemo = isDemo
        self.networks = networks; self.history = history; self.link = link; self.selectedID = selectedID
    }
}
public struct WorkspaceSummary: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let savedAt: Date
    public let networkCount: Int
    public let isDemo: Bool
}
public actor WorkspaceRepository {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func save(_ workspace: SavedWorkspace) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(workspace).write(to: directory.appendingPathComponent(workspace.id.uuidString + ".json"), options: .atomic)
    }
    public func load(_ id: UUID) throws -> SavedWorkspace {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SavedWorkspace.self, from: Data(contentsOf: directory.appendingPathComponent(id.uuidString + ".json")))
    }
    public func list() throws -> [WorkspaceSummary] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return urls.compactMap { url -> WorkspaceSummary? in
            guard url.pathExtension == "json", let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  let workspace = try? load(id) else { return nil }
            return WorkspaceSummary(id: workspace.id, name: workspace.name, savedAt: workspace.savedAt,
                                    networkCount: workspace.networks.count, isDemo: workspace.isDemo)
        }.sorted { $0.savedAt > $1.savedAt }
    }
}
