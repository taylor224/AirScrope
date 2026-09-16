import SwiftUI

@main
struct AirScopeApp: App {
    @StateObject private var store = WiFiStore()
    var body: some Scene {
        WindowGroup("AirScope") {
            ContentView(store: store)
                .preferredColorScheme(AppSettings.shared.appearance.colorScheme)
                .environment(\.locale, Locale(identifier: AppSettings.shared.language.resolved))
                .frame(minWidth: 1120, minHeight: 740)
                .task { store.start() }
        }
        .defaultSize(width: 1360, height: 920)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(L("스캔")) {
                Button(L("지금 스캔")) { store.scan() }.keyboardShortcut("r")
                Button(L(store.isRunning ? "일시 정지" : "다시 시작")) { store.toggleRunning() }.keyboardShortcut("p")
                Divider()
                Button(L("JSON 세션 내보내기…")) { store.export(json: true) }.keyboardShortcut("e")
                Button(L("CSV 스캔 내보내기…")) { store.export(json: false) }
                Divider()
                Button(L(store.isDemo ? "실제 Wi-Fi로 전환" : "데모 살펴보기")) { store.switchMode() }
            }
        }
    }
}
