import SwiftUI
import Observation

@MainActor @Observable final class AppSettings {
    static let shared = AppSettings()
    var language: AppLanguage { didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") } }
    var appearance: AppAppearance { didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance") } }
    private init() {
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "system") ?? .system
        appearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appAppearance") ?? "system") ?? .system
    }
}
enum AppLanguage: String, CaseIterable {
    case system, ko, en, zh
    @MainActor var title: String { switch self { case .system: L("시스템 설정에 따름"); case .ko: "한국어"; case .en: "English"; case .zh: "简体中文" } }
    var resolved: String {
        if self != .system { return rawValue }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ko") ? "ko" : preferred.hasPrefix("zh") ? "zh" : "en"
    }
}
enum AppAppearance: String, CaseIterable {
    case system, light, dark
    @MainActor var title: String { switch self { case .system: L("시스템 설정에 따름"); case .light: L("라이트 모드"); case .dark: L("다크 모드") } }
    var colorScheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}

/// This sheet edits a stable snapshot. Live scan publications cannot recreate
/// an open settings submenu or reset the controls while the user is editing.
struct SettingsView: View {
    let interfaces: [String]
    let apply: (String?, Double, Bool) -> Void
    @State private var selectedInterface: String
    @State private var interval: Double
    @State private var hidden: Bool
    @Bindable private var preferences = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    init(interfaces: [String], currentInterface: String?, interval: Double, hidden: Bool, apply: @escaping (String?, Double, Bool) -> Void) {
        self.interfaces = interfaces; self.apply = apply
        _selectedInterface = State(initialValue: currentInterface ?? "")
        _interval = State(initialValue: interval); _hidden = State(initialValue: hidden)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(L("설정")).font(.system(size: 28, weight: .semibold))
            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 24) {
                GridRow {
                    Text(L("네트워크 어댑터"))
                    Picker(L("네트워크 어댑터"), selection: $selectedInterface) {
                        Text(L("자동 선택")).tag("")
                        ForEach(interfaces, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden()
                }
                GridRow {
                    Text(L("스캔 간격"))
                    Picker(L("스캔 간격"), selection: $interval) {
                        ForEach([5.0, 10, 20, 30], id: \.self) { Text(L("{0}초", String(Int($0)))).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden()
                }
                GridRow { Text(L("숨겨진 네트워크")); Toggle(L("스캔에 포함"), isOn: $hidden).toggleStyle(.switch) }
                GridRow {
                    Text(L("언어"))
                    Picker(L("언어"), selection: $preferences.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden()
                }
                GridRow {
                    Text(L("화면 모드"))
                    Picker(L("화면 모드"), selection: $preferences.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden()
                }
            }.font(.system(size: 14))
            HStack {
                Text(L("스캔 설정은 적용을 누르면 반영됩니다.")).font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer()
                Button(L("적용")) {
                    apply(selectedInterface.isEmpty ? nil : selectedInterface, interval, hidden); dismiss()
                }.buttonStyle(PillButton(primary: true)).keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(width: 620).background(Theme.canvas).foregroundStyle(Theme.ink)
            .preferredColorScheme(preferences.appearance.colorScheme)
    }
}

struct TermInfo: View {
    let term: String
    @State private var showing = false
    var body: some View {
        Button { showing.toggle() } label: { Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(Theme.blue) }
            .buttonStyle(PressButton()).help(L("{0} 설명", term)).accessibilityLabel(L("{0} 설명", term))
            .popover(isPresented: $showing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(termTitle(term)).font(.system(size: 17, weight: .semibold))
                    Text(L("term." + term)).font(.system(size: 14)).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
                }.padding(24).frame(width: 330).foregroundStyle(Theme.ink).background(Theme.canvas)
            }
    }
}

@MainActor func termTitle(_ term: String) -> String {
    switch term { case "Manufacturer": L("제조사"); case "Channel": L("채널"); case "Width": L("폭"); default: term }
}
