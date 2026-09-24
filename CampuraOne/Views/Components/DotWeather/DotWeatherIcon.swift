import SwiftUI

/// Original monochrome dot-matrix weather kit, inspired by Nothing OS.
/// No bitmap/SVG assets and no interpolated animation. Default size: 64 pt.
enum DotWeatherCondition: String, CaseIterable, Identifiable {
    case clear, partlyCloudy, cloudy, overcast, drizzle, rain, heavyRain
    case thunderstorm, snow, heavySnow, sleet, hail, fog, haze, dust, wind, unknown
    var id: Self { self }
    var title: String {
        switch self {
        case .clear: "晴"
        case .partlyCloudy: "多云"
        case .cloudy: "阴云"
        case .overcast: "阴"
        case .drizzle: "小雨"
        case .rain: "雨"
        case .heavyRain: "大雨"
        case .thunderstorm: "雷雨"
        case .snow: "雪"
        case .heavySnow: "大雪"
        case .sleet: "雨夹雪"
        case .hail: "冰雹"
        case .fog: "雾"
        case .haze: "霾"
        case .dust: "扬沙"
        case .wind: "大风"
        case .unknown: "天气未知"
        }
    }
}

struct DotWeatherIcon: View {
    let condition: DotWeatherCondition
    var isNight = false
    var size: CGFloat = 64
    var tint: Color = .primary
    var flashing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.8)) { timeline in
            let tick = flashing && !reduceMotion && scenePhase == .active
                ? Int(timeline.date.timeIntervalSince1970 / 0.8) % 2 : 0
            Canvas { context, canvas in
                let step = min(canvas.width, canvas.height) / 32
                let origin = CGPoint(x: (canvas.width - 32 * step) / 2, y: (canvas.height - 32 * step) / 2)
                for y in 0..<32 {
                    for x in 0..<32 where lit(x: x, y: y, tick: tick) {
                        let rect = CGRect(x: origin.x + (CGFloat(x) + 0.14) * step,
                                          y: origin.y + (CGFloat(y) + 0.14) * step,
                                          width: step * 0.72, height: step * 0.72)
                        context.fill(Path(ellipseIn: rect), with: .color(tint))
                    }
                }
            }
        }
        .frame(width: max(1, size), height: max(1, size))
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((isNight ? "夜间，" : "") + condition.title)
    }

    private func ring(_ x: Int, _ y: Int, _ cx: Int, _ cy: Int, _ radius: Double) -> Bool {
        abs(hypot(Double(x - cx), Double(y - cy)) - radius) < 0.7
    }

    private func cloud(_ x: Int, _ y: Int) -> Bool {
        let inside: (Int, Int) -> Bool = { a, b in
            (a >= 7 && a <= 26 && b >= 13 && b <= 19)
            || hypot(Double(a - 12), Double(b - 13)) <= 5
            || hypot(Double(a - 20), Double(b - 11)) <= 6
            || hypot(Double(a - 26), Double(b - 15)) <= 4
        }
        return inside(x, y) && (!inside(x - 1, y) || !inside(x + 1, y) || !inside(x, y - 1) || !inside(x, y + 1))
    }

    private func sky(_ x: Int, _ y: Int, compact: Bool, tick: Int) -> Bool {
        let cx = compact ? 9 : 16, cy = compact ? 9 : 15
        let radius = compact ? 4.0 : 7.0
        if isNight {
            let distance = hypot(Double(x - cx), Double(y - cy))
            let cutout = hypot(Double(x - cx - 4), Double(y - cy + 3))
            return (distance < radius && cutout > radius - 1)
                || (!compact && tick == 0 && ((x == 25 && y == 6) || (x == 24 && y == 23)))
        }
        let dx = abs(x - cx), dy = abs(y - cy)
        let rays = (dx == 0 && Double(dy) >= radius + 3 && Double(dy) <= radius + 5)
            || (dy == 0 && Double(dx) >= radius + 3 && Double(dx) <= radius + 5)
            || (dx == dy && Double(dx) >= radius && Double(dx) <= radius + 1)
        return ring(x, y, cx, cy, radius) || (rays && (tick == 0 || !compact))
    }

    private func lit(x: Int, y: Int, tick: Int) -> Bool {
        switch condition {
        case .clear: return sky(x, y, compact: false, tick: tick)
        case .partlyCloudy: return cloud(x, y) || (y < 12 && sky(x, y, compact: true, tick: tick))
        case .cloudy: return cloud(x, y)
        case .overcast: return cloud(x, y) || (y == 23 && x >= 9 && x <= 25 && x % 2 == tick)
        case .fog, .haze, .dust:
            let band = [11, 16, 21, 26].contains(y) && x >= 5 && x <= 27
            return band && (x + tick * 2 + y) % (condition == .fog ? 7 : 4) != 0
        case .wind:
            return ([10, 16, 22].contains(y) && x >= 4 + tick * 2 && x <= 23)
                || (x > 21 && (ring(x, y, 23, 8, 2) || ring(x, y, 25, 20, 2)))
        case .unknown:
            return (y < 14 && ring(x, y, 16, 11, 5)) || (x == 16 && (14...20).contains(y)) || (x == 16 && y == 25)
        default:
            if cloud(x, y) { return true }
            if condition == .thunderstorm {
                return tick == 0 && ((y >= 20 && y <= 24 && x == 19 - (y - 20))
                    || (y == 24 && (15...20).contains(x)) || (y > 24 && y <= 29 && x == 20 - (y - 24)))
            }
            guard (21...29).contains(y) else { return false }
            let snowy = condition == .snow || condition == .heavySnow || condition == .sleet
            if snowy {
                for cx in condition == .heavySnow ? [8, 16, 24] : [11, 23] {
                    let cy = 24 + tick * 2
                    if (abs(x - cx) <= 2 && y == cy) || (x == cx && abs(y - cy) <= 2) { return true }
                }
                if condition != .sleet { return false }
            }
            if condition == .hail {
                return [9, 17, 25].contains(x) && [23 + tick * 2, 27 + tick].contains(y)
            }
            let columns = condition == .heavyRain ? [7, 12, 17, 22, 27] : condition == .drizzle ? [12, 24] : [10, 18, 26]
            return columns.contains(x + (y - 21) / 3) && (y + tick * 2) % 5 < 3
        }
    }
}

#Preview("点阵天气 · 全部状态") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))]) {
            ForEach(DotWeatherCondition.allCases) { condition in
                VStack {
                    DotWeatherIcon(condition: condition)
                    Text(condition.title).font(.caption)
                }
            }
            DotWeatherIcon(condition: .clear, isNight: true)
            DotWeatherIcon(condition: .partlyCloudy, isNight: true)
        }.padding()
    }
}
