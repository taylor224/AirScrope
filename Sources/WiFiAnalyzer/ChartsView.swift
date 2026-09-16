import SwiftUI
import Charts
import WiFiCore

struct SpectrumView: View {
    let networks: [NetworkRecord]
    @Binding var selectedID: String?
    @State private var scope = "2.4 / 5 GHz"
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(Theme.blueOnDark).frame(width: 7, height: 7)
                    Text(L("선택한 AP")).foregroundStyle(Theme.darkMuted)
                    Circle().fill(Theme.darkMuted.opacity(0.5)).frame(width: 7, height: 7).padding(.leading, 12)
                    Text(L("주변 AP")).foregroundStyle(Theme.darkMuted)
                }.font(.system(size: 12))
                Spacer()
                Picker(L("그래프 대역"), selection: $scope) {
                    Text("2.4 / 5 GHz").tag("2.4 / 5 GHz"); Text("6 GHz").tag("6 GHz")
                }.pickerStyle(.segmented).frame(width: 210).colorScheme(.dark)
            }
            if scope == "6 GHz" {
                ChannelPlot(networks: networks.filter { $0.band == .six }, band: .six, selectedID: $selectedID)
            } else {
                HStack(spacing: 40) {
                    ChannelPlot(networks: networks.filter { $0.band == .two }, band: .two, selectedID: $selectedID)
                    ChannelPlot(networks: networks.filter { $0.band == .five }, band: .five, selectedID: $selectedID)
                }
            }
            Text(L("채널 폭과 RSSI로 그린 분포입니다. RF 스펙트럼 실측이 아니며, 폭이 미확인된 AP는 점선으로 표시합니다."))
                .font(.system(size: 12)).foregroundStyle(Theme.darkMuted)
        }
    }
}

struct ChannelPlot: View {
    let networks: [NetworkRecord]
    let band: WiFiBand
    @Binding var selectedID: String?
    private var domain: ClosedRange<Double> {
        switch band { case .two: 2400...2495; case .five: 5150...5900; case .six: 5925...7125; case .unknown: 0...1 }
    }
    private var ticks: [Int] {
        switch band { case .two: [1,3,6,9,11,14]; case .five: [36,64,100,128,149,177]; case .six: [1,33,65,97,129,161,193,233]; case .unknown: [] }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(band.rawValue).font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("\(networks.count) APs").font(.system(size: 12)).foregroundStyle(Theme.darkMuted)
            }
            GeometryReader { geometry in
                Canvas { context, size in draw(context: &context, size: size) }
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { select(at: $0.location, size: geometry.size) })
                    .accessibilityLabel(L("{0} 채널 분포. {1}개 AP. 네트워크 목록에서도 선택할 수 있습니다.", band.rawValue, String(networks.count)))
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func select(at point: CGPoint, size: CGSize) {
        let frequency = domain.lowerBound + (point.x - 34) / max(1, size.width - 44) * (domain.upperBound - domain.lowerBound)
        let rssi = -25 - (point.y - 24) / max(1, size.height - 48) * 75
        let candidates = networks.filter {
            if let range = $0.frequencyRange { return range.contains(frequency) }
            return $0.band.frequency(channel: $0.channel).map { abs($0 - frequency) < 8 } ?? false
        }
        selectedID = candidates.min { abs(Double($0.rssi) - rssi) < abs(Double($1.rssi) - rssi) }?.id ?? selectedID
    }
    private func draw(context: inout GraphicsContext, size: CGSize) {
        let left = 34.0, right = size.width - 10, top = 24.0, bottom = max(top + 10, size.height - 24)
        func x(_ f: Double) -> Double { left + (f - domain.lowerBound) / (domain.upperBound - domain.lowerBound) * (right - left) }
        func y(_ rssi: Double) -> Double { top + (-25 - max(-100, min(-25, rssi))) / 75 * (bottom - top) }
        for value in [-30, -50, -70, -90] {
            var line = Path(); line.move(to: CGPoint(x: left, y: y(Double(value)))); line.addLine(to: CGPoint(x: right, y: y(Double(value))))
            context.stroke(line, with: .color(Color.white.opacity(0.10)), style: StrokeStyle(lineWidth: 1, dash: [2,4]))
            context.draw(Text("\(value)").font(.system(size: 10)).foregroundColor(Theme.darkMuted), at: CGPoint(x: 13, y: y(Double(value))))
        }
        for channel in ticks {
            guard let frequency = band.frequency(channel: channel) else { continue }
            context.draw(Text("\(channel)").font(.system(size: 10)).foregroundColor(Theme.darkMuted), at: CGPoint(x: x(frequency), y: bottom + 15))
        }
        let sorted = networks.filter { $0.validRSSI != nil }.sorted { a,b in
            if a.id == selectedID { return false }; if b.id == selectedID { return true }; return a.rssi < b.rssi
        }
        for n in sorted {
            let selected = n.id == selectedID
            let color = selected ? Theme.blueOnDark : Theme.darkMuted
            guard let primary = band.frequency(channel: n.channel) else { continue }
            let ypos = y(Double(n.rssi))
            if let range = n.frequencyRange {
                let lower = max(left, x(range.lowerBound)), upper = min(right, x(range.upperBound))
                guard upper > lower else { continue }
                let shoulder = min(10, (upper - lower) * 0.13)
                var path = Path()
                path.move(to: CGPoint(x: lower, y: bottom))
                path.addLine(to: CGPoint(x: lower + shoulder, y: ypos + 5))
                path.addQuadCurve(to: CGPoint(x: lower + shoulder + 4, y: ypos), control: CGPoint(x: lower + shoulder, y: ypos))
                path.addLine(to: CGPoint(x: upper - shoulder - 4, y: ypos))
                path.addQuadCurve(to: CGPoint(x: upper - shoulder, y: ypos + 5), control: CGPoint(x: upper - shoulder, y: ypos))
                path.addLine(to: CGPoint(x: upper, y: bottom)); path.closeSubpath()
                context.fill(path, with: .color(color.opacity(selected ? 0.16 : 0.025)))
                context.stroke(path, with: .color(color.opacity(selected ? 1 : 0.32)), lineWidth: selected ? 2 : 1)
            } else {
                var path = Path(); path.move(to: CGPoint(x: x(primary), y: bottom)); path.addLine(to: CGPoint(x: x(primary), y: ypos))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: [3,3]))
            }
            if selected {
                let point = CGPoint(x: min(right - 55, max(left + 55, x(primary))), y: ypos - 12)
                context.draw(Text(String(networkTitle(n).prefix(22))).font(.system(size: 11, weight: .semibold)).foregroundColor(color), at: point)
            }
        }
        if networks.isEmpty {
            context.draw(Text(L("관측된 네트워크 없음")).font(.system(size: 14)).foregroundColor(Theme.darkMuted), at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
    }
}

struct HistoryView: View {
    let network: NetworkRecord?
    let samples: [SignalSample]
    var referenceDate: Date? = nil
    @State private var minutes = 5
    @State private var source = "Scan"
    private var points: [SignalSample] {
        samples.filter { $0.networkID == network?.id && $0.date >= (referenceDate ?? Date()).addingTimeInterval(Double(-minutes * 60)) && (source == "Link" ? $0.source == "CoreWLAN link" : $0.source != "CoreWLAN link") }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(network.map(networkTitle) ?? L("네트워크 선택")).font(.system(size: 21, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 16) {
                        Label("RSSI", systemImage: "circle.fill").foregroundStyle(Theme.blue)
                        Label("Noise", systemImage: "minus").foregroundStyle(Theme.muted)
                    }.font(.system(size: 12))
                }
                Spacer()
                Picker(L("측정"), selection: $source) { Text(L("AP 스캔")).tag("Scan"); Text(L("연결 링크")).tag("Link") }
                    .pickerStyle(.segmented).frame(width: 200)
                Picker(L("기간"), selection: $minutes) { Text(L("1분")).tag(1); Text(L("5분")).tag(5); Text(L("15분")).tag(15) }.frame(width: 130)
            }
            if points.isEmpty {
                EmptyState(symbol: "waveform.path", title: "신호 이력을 기다립니다", detail: source == "Link" ? "연결 링크는 현재 Mac이 연결한 AP에서만 측정합니다." : "선택한 AP의 스캔이 완료되면 여기에 기록됩니다.")
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(x: .value(L("시간"), point.date), y: .value("dBm", point.rssi), series: .value("측정", "RSSI"))
                            .foregroundStyle(Theme.blue).lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value(L("시간"), point.date), y: .value("dBm", point.rssi)).foregroundStyle(Theme.blue).symbolSize(points.count > 100 ? 3 : 14)
                        if let noise = point.noise {
                            LineMark(x: .value(L("시간"), point.date), y: .value("dBm", noise), series: .value("측정", "Noise"))
                                .foregroundStyle(Theme.muted).lineStyle(StrokeStyle(lineWidth: 1, dash: [5,5]))
                        }
                    }
                }.chartYScale(domain: -105 ... -20)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisGridLine().foregroundStyle(Theme.softLine)
                        AxisValueLabel(format: .dateTime.hour().minute().second()).foregroundStyle(Theme.muted)
                    } }
                    .chartYAxis { AxisMarks(position: .leading, values: [-100,-80,-60,-40,-20]) { _ in
                        AxisGridLine(stroke: StrokeStyle(dash: [2,4])).foregroundStyle(Theme.line)
                        AxisValueLabel().foregroundStyle(Theme.muted)
                    } }
            }
            HStack {
                Text(L("{0}개 표본", String(points.count)) + " · " + L(source == "Link" ? "연결 AP / 1초 폴링" : "주변 AP / 스캔 완료 시 기록"))
                Spacer(); Text(L("최대 15분 보관 · dBm"))
            }.font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }
}
