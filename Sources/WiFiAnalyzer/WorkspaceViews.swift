import SwiftUI
import Observation
import WiFiCore

@MainActor @Observable final class WorkspaceLibrary {
    static let shared = WorkspaceLibrary()
    private let repository: WorkspaceRepository
    var items: [WorkspaceSummary] = []
    var error: String?
    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        repository = WorkspaceRepository(directory: support.appendingPathComponent("AirScope/Workspaces", isDirectory: true))
    }
    func refresh() async {
        do { items = try await repository.list() } catch { self.error = error.localizedDescription }
    }
    func save(_ snapshot: SavedWorkspace) async throws {
        try await repository.save(snapshot); await refresh()
    }
    func open(_ id: UUID, into store: WiFiStore) async {
        do { store.openWorkspace(try await repository.load(id)) } catch { self.error = error.localizedDescription }
    }
}

struct SaveWorkspaceView: View {
    let snapshot: SavedWorkspace
    let completed: () -> Void
    @State private var name: String
    @State private var saving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    init(snapshot: SavedWorkspace, completed: @escaping () -> Void) {
        self.snapshot = snapshot; self.completed = completed
        _name = State(initialValue: snapshot.savedAt.formatted(date: .abbreviated, time: .shortened))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("워크스페이스에 저장")).font(.system(size: 24, weight: .semibold))
            Text(L("현재 필터가 적용된 {0}개 네트워크와 신호 이력을 저장합니다.", String(snapshot.networks.count)))
                .font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(5)
            TextField(L("이름"), text: $name).textFieldStyle(.roundedBorder)
            if let error { Text(error).font(.system(size: 12)) }
            HStack {
                Button(L("취소")) { dismiss() }.buttonStyle(LinkButton()).keyboardShortcut(.cancelAction)
                Spacer()
                Button(L(saving ? "저장 중…" : "저장")) {
                    saving = true
                    var saved = snapshot; saved.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        do { try await WorkspaceLibrary.shared.save(saved); completed(); dismiss() }
                        catch { self.error = error.localizedDescription; saving = false }
                    }
                }.buttonStyle(PillButton(primary: true)).disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(width: 500).background(Theme.canvas).foregroundStyle(Theme.ink)
    }
}
struct WorkspaceListView: View {
    @ObservedObject var store: WiFiStore
    let opened: () -> Void
    @State private var library = WorkspaceLibrary.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(L("워크스페이스")).font(.system(size: 40, weight: .semibold)).tracking(-0.37)
            Text(L("저장한 네트워크 목록과 이력을 다시 엽니다.")).font(.system(size: 17)).foregroundStyle(Theme.muted)
            if let error = library.error { Text(error).font(.system(size: 14)) }
            if library.items.isEmpty {
                EmptyState(symbol: "folder", title: L("저장한 목록이 없습니다"), detail: L("네트워크 화면의 목록 저장 버튼으로 현재 목록을 저장하세요."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(library.items) { item in
                            HStack(spacing: 24) {
                                Image(systemName: "folder").font(.system(size: 28, weight: .light)).foregroundStyle(Theme.blue)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.name).font(.system(size: 17, weight: .semibold))
                                    Text(L("{0}개 네트워크", String(item.networkCount)) + " · " + item.savedAt.formatted(date: .abbreviated, time: .shortened) + (item.isDemo ? " · " + L("샘플 데이터") : ""))
                                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Button(L("열기")) { Task { await library.open(item.id, into: store); if store.workspace?.id == item.id { opened() } } }.buttonStyle(PillButton())
                            }.padding(24).utilityCard()
                        }
                    }
                }
            }
        }.padding(.vertical, 32).pageContent().background(Theme.parchment).task { await library.refresh() }
    }
}
