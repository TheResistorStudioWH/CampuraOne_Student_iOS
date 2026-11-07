import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CampuraOneLiveActivities: WidgetBundle {
    var body: some Widget { PromotionLiveActivityWidget() }
}

struct PromotionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PromotionActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: "tag.fill").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.attributes.title).font(.headline).lineLimit(2)
                        Text(context.attributes.merchantName).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    countdown(context).font(.title2.monospacedDigit().bold()).foregroundStyle(.orange)
                        .multilineTextAlignment(.trailing)
                }
                Text("计划开始 \(context.state.startsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
            .activitySystemActionForegroundColor(.primary)
            .widgetURL(context.attributes.detailURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "tag.fill").foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        Text(context.attributes.title).font(.headline).lineLimit(2)
                        Text(context.attributes.merchantName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("计划开始 \(context.state.startsAt.formatted(date: .omitted, time: .shortened))").font(.caption)
                        Spacer(minLength: 8)
                        countdown(context).font(.title2.monospacedDigit().bold()).foregroundStyle(.orange)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: "tag.fill").foregroundStyle(.orange)
            } compactTrailing: {
                countdown(context).font(.caption.monospacedDigit()).frame(maxWidth: 80)
            } minimal: {
                Image(systemName: context.isStale ? "clock.badge.checkmark" : "hourglass").foregroundStyle(.orange)
            }
            .widgetURL(context.attributes.detailURL)
            .keylineTint(.orange)
        }
    }
    @ViewBuilder private func countdown(_ context: ActivityViewContext<PromotionActivityAttributes>) -> some View {
        if context.isStale {
            Text("计划开始时间已到").font(.caption).lineLimit(2)
        } else {
            Text(timerInterval: context.state.countdownFrom...context.state.startsAt, countsDown: true)
                .monospacedDigit().minimumScaleFactor(0.7)
                .accessibilityLabel("距离计划开始")
        }
    }
}

#if DEBUG
private let previewAttributes = PromotionActivityAttributes(scopeID: "preview", saleID: 1,
    title: "课间限定抢购", merchantName: "校园饮品店",
    detailURL: URL(string: "campuraone://promotion/1?scope=preview")!)
#Preview("促销 · 锁屏", as: .content, using: previewAttributes) {
    PromotionLiveActivityWidget()
} contentStates: {
    PromotionActivityAttributes.ContentState(countdownFrom: .now, startsAt: .now.addingTimeInterval(1800))
}
#Preview("促销 · 灵动岛展开", as: .dynamicIsland(.expanded), using: previewAttributes) {
    PromotionLiveActivityWidget()
} contentStates: {
    PromotionActivityAttributes.ContentState(countdownFrom: .now, startsAt: .now.addingTimeInterval(90))
}
#Preview("促销 · 灵动岛紧凑", as: .dynamicIsland(.compact), using: previewAttributes) {
    PromotionLiveActivityWidget()
} contentStates: {
    PromotionActivityAttributes.ContentState(countdownFrom: .now, startsAt: .now.addingTimeInterval(90))
}
#Preview("促销 · 灵动岛最小", as: .dynamicIsland(.minimal), using: previewAttributes) {
    PromotionLiveActivityWidget()
} contentStates: {
    PromotionActivityAttributes.ContentState(countdownFrom: .now, startsAt: .now.addingTimeInterval(90))
}
#endif
