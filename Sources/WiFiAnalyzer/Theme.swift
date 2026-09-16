import SwiftUI
import WiFiCore

/// Color and spacing tokens documented in docs/DESIGN.md. Blue is the only accent.
enum Theme {
    static let action = Color(hex: 0x0066cc)
    static let blue = adaptive(0x0066cc, 0x2997ff)
    static let focus = Color(hex: 0x0071e3)
    static let blueOnDark = Color(hex: 0x2997ff)
    static let ink = adaptive(0x1d1d1f, 0xf5f5f7)
    static let muted = adaptive(0x6e6e73, 0xa1a1a6)
    static let secondary = adaptive(0x333333, 0xcccccc)
    static let canvas = adaptive(0xffffff, 0x1d1d1f)
    static let parchment = adaptive(0xf5f5f7, 0x141414)
    static let pearl = adaptive(0xfafafc, 0x252527)
    static let line = adaptive(0xe0e0e0, 0x424245)
    static let softLine = adaptive(0xf0f0f0, 0x333336)
    static let dark = Color(hex: 0x272729)
    static let darkMuted = Color(hex: 0xcccccc)
    static let pageWidth: CGFloat = 1320
    static let cardRadius: CGFloat = 18
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
                           blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
}
extension Color {
    fileprivate init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
struct PillButton: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .regular))
            .padding(.horizontal, 20).frame(minHeight: 40)
            .foregroundStyle(primary ? Color.white : Theme.blue)
            .background(primary ? Theme.action : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(primary ? Color.clear : Theme.blue, lineWidth: 1))
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
struct LinkButton: ButtonStyle {
    var onDark = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(onDark ? Theme.blueOnDark : Theme.blue)
            .contentShape(Rectangle()).scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
struct FilterChip: View {
    let title: String
    var count: Int? = nil
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(L(title))
                if let count { Text("\(count)").foregroundStyle(Theme.muted).monospacedDigit() }
            }.font(.system(size: 14)).padding(.horizontal, 16).frame(height: 40)
                .foregroundStyle(selected ? Theme.blue : Theme.ink)
                .background(Theme.canvas, in: Capsule())
                .overlay(Capsule().stroke(selected ? Theme.focus : Theme.line, lineWidth: selected ? 2 : 1))
        }.buttonStyle(PressButton()).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct PressButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
struct Eyebrow: View {
    let text: String
    var dark = false
    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold)).tracking(1.2)
            .foregroundStyle(dark ? Theme.darkMuted : Theme.muted)
    }
}
struct SignalBars: View {
    let value: Int?
    var color: Color = Theme.blue
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1).fill((value ?? -127) >= -90 + index * 10 ? color : Theme.line)
                    .frame(width: 4, height: CGFloat(5 + index * 3))
            }
        }.accessibilityLabel("RSSI \(value.map(String.init) ?? "unknown") dBm")
    }
}
struct EmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 40, weight: .light)).foregroundStyle(Theme.muted)
            Text(L(title)).font(.system(size: 24, weight: .semibold)).tracking(-0.3)
            Text(L(detail)).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).lineSpacing(5)
        }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
extension View {
    func utilityCard() -> some View {
        background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.line, lineWidth: 1))
    }
    func pageContent() -> some View {
        frame(maxWidth: Theme.pageWidth).padding(.horizontal, 40).frame(maxWidth: .infinity)
    }
}
