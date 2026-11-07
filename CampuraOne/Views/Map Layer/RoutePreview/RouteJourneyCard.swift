import SwiftUI
import PetaKitUIX

/// A compact "before leaving" summary remains visible when the sheet is collapsed.
struct RouteTravelSummary: View {
    let plan: NavigationPlan
    var body: some View {
        if let timing = plan.timing, let path = plan.route {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    duration(timing)
                    Spacer(minLength: 0)
                    distanceAndArrival(timing, path)
                }
                VStack(alignment: .leading, spacing: 8) {
                    duration(timing)
                    distanceAndArrival(timing, path)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("route.travelSummary")
        }
    }

    private func duration(_ timing: NavigationTiming) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(max(1, Int(ceil(Double(timing.totalSeconds) / 60))))")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit().contentTransition(.numericText())
            Text("分钟").font(.headline)
        }.foregroundStyle(Color.accentColor).fixedSize()
    }

    private func distanceAndArrival(_ timing: NavigationTiming, _ path: NavigationRoute) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(path.distanceMeters.formatted(.number.precision(.fractionLength(0))) + " 米", systemImage: "figure.walk")
                .font(.subheadline.weight(.semibold))
            Text("预计 \(timing.estimatedArrival.formatted(date: .omitted, time: .shortened)) 到达")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// The path reads like a short itinerary rather than a wall of independent labels.
struct RouteJourneyCard: View {
    let plan: NavigationPlan
    let originName: String
    let changeOrigin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            endpoint(title: originName, caption: "起点", symbol: "circle.fill", tint: .accentColor) {
                MapPanelIconButton(title: "修改起点", symbol: "pencil", tint: .accentColor, action: changeOrigin)
            }
            ForEach(plan.waypoints) { stop in
                connector
                endpoint(title: stop.name, caption: "途经 · 停留约 \(max(1, Int(ceil(Double(stop.dwellSeconds) / 60)))) 分钟",
                         symbol: "mappin.circle.fill", tint: .orange) { EmptyView() }
            }
            connector
            endpoint(title: plan.destination?.name ?? "目的地", caption: "终点", symbol: "mappin.circle.fill", tint: .orange) { EmptyView() }
        }
        .mapPanelCard()
        .accessibilityIdentifier("route.itinerary")
    }

    private var connector: some View {
        Rectangle().fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 14).padding(.leading, 9)
            .accessibilityHidden(true)
    }

    private func endpoint<Accessory: View>(title: String, caption: String, symbol: String, tint: Color,
                                          @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(tint).frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(caption).font(.caption).foregroundStyle(.secondary)
                Text(title).font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            accessory()
        }
    }
}

struct RouteScheduleAllowance: View {
    let plan: NavigationPlan

    var body: some View {
        if let timing = plan.timing, timing.remainingSeconds != nil || plan.schedule != nil {
            VStack(alignment: .leading, spacing: 12) {
                if let remaining = timing.remainingSeconds {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: remaining >= 0 ? "clock.badge.checkmark" : "clock.badge.exclamationmark")
                            .font(.title3).foregroundStyle(remaining >= 0 ? Color.green : Color.orange)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(remaining >= 0 ? "仍有 \(margin(remaining))余量" : "可能晚到约 \(max(1, Int(ceil(Double(-remaining) / 60)))) 分钟")
                                .font(.headline).foregroundStyle(.primary)
                            Text("按保守到达时间及提前量估算").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let schedule = plan.schedule {
                    if timing.remainingSeconds != nil { Divider() }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "book.closed").foregroundStyle(.secondary).frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(schedule.title).font(.subheadline.weight(.semibold))
                            Text(schedule.location).font(.subheadline).foregroundStyle(.secondary)
                            Text("\(Date(timeIntervalSince1970: schedule.startAt).formatted(date: .omitted, time: .shortened)) 开始上课")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .mapPanelCard()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("route.timeAllowance")
        }
    }

    private func margin(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) 秒" : "\(seconds / 60) 分钟"
    }
}
