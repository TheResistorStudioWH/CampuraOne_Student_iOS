import SwiftUI
import PetaKitUIX

/// Presentation data only. A future weather provider can replace this snapshot
/// without changing the header or requesting location access from this view.
struct HomeWeatherSnapshot {
    var city: String
    var district: String
    var temperatureCelsius: Double?
    var condition: DotWeatherCondition
    var isNight: Bool
    var isDemo: Bool

    static let demo = HomeWeatherSnapshot(
        city: "武汉市", district: "江夏区", temperatureCelsius: 24,
        condition: .rain, isNight: false, isDemo: true
    )

    var locationText: String {
        [city, district].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var temperatureText: String {
        guard let temperatureCelsius, temperatureCelsius.isFinite else { return "—°C" }
        return temperatureCelsius.formatted(.number.precision(.fractionLength(0))) + "°C"
    }
}

struct HomeWeatherBadge: View {
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var snapshot: HomeWeatherSnapshot = .demo
    // The dashboard has an invisible duplicate header for banner alignment.
    // That layout placeholder must not start a second presentation timer.
    var isPresentationActive = true

    @State private var showsLocation = true
    @State private var manuallySwitched = false

    var body: some View {
        ZStack(alignment: .trailing) {
            locationModule
                .opacity(showsLocation ? 1 : 0)
                .offset(y: reduceMotion || showsLocation ? 0 : -7)
                .scaleEffect(reduceMotion || showsLocation ? 1 : 0.96, anchor: .trailing)
            weatherModule
                .opacity(showsLocation ? 0 : 1)
                .offset(y: reduceMotion || !showsLocation ? 0 : 7)
                .scaleEffect(reduceMotion || !showsLocation ? 1 : 0.96, anchor: .trailing)
        }
        .frame(width: 152, height: 44, alignment: .trailing)
        .animation(
            reduceMotion ? .easeInOut(duration: 0.18) : .smooth(duration: 0.3),
            value: showsLocation
        )
        .contentShape(Rectangle())
        .beButton {
            manuallySwitched = true
            showsLocation.toggle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsLocation ? "地区，\(snapshot.locationText)" : "\(snapshot.temperatureText)，\(snapshot.condition.title)")
        .accessibilityValue(snapshot.isDemo ? "演示数据，非实时定位或天气" : "")
        .accessibilityHint(showsLocation ? "轻点切换天气" : "轻点切换地区")
        .task {
            guard isPresentationActive else { return }
            showsLocation = true
            manuallySwitched = false
            do {
                try await Task.sleep(for: .seconds(2))
                try Task.checkCancellation()
                guard !manuallySwitched else { return }
                showsLocation = false
            } catch {
                // Leaving the page cancels the pending automatic switch.
            }
        }
    }

    private var locationModule: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.system(size: 12, weight: .medium))
            Text(snapshot.locationText)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityHidden(true)
    }

    private var weatherModule: some View {
        HStack(spacing: 4) {
            Text(snapshot.temperatureText)
                .font(.system(size: 23, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            DotWeatherIcon(
                condition: snapshot.condition,
                isNight: snapshot.isNight,
                size: 44,
                flashing: isPresentationActive && !showsLocation
            )
        }
        .accessibilityHidden(true)
    }
}

#Preview("姓名行 · 演示天气") {
    HStack {
        Text("人类1同学").font(.system(size: 25)).lineLimit(1)
        Spacer(minLength: 8)
        HomeWeatherBadge()
    }
    .padding()
    .preferredColorScheme(.dark)
}
