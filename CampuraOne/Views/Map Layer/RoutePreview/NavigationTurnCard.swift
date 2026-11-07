import SwiftUI
struct NavigationTurnCard: View {
    @ObservedObject var route: RoutePreviewStore
    @ObservedObject private var navigation = StudentNavigationStore.shared

    var body: some View {
        if navigation.isGuiding, navigation.isCurrent {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 30, weight: .bold)).frame(width: 42)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.accentColor.opacity(0.2)))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
            .accessibilityElement(children: .combine)
        }
    }
    private var symbol: String {
        if route.hasArrived { return "checkmark.circle.fill" }
        if route.waitingAtStop { return "cup.and.saucer.fill" }
        if route.guidanceLocationMessage != nil { return "location.slash" }
        if let distance = route.distanceToNextStop, distance <= (route.guidanceSample?.distanceToTurn ?? 0) + 1 {
            return "mappin.circle.fill"
        }
        return route.guidanceSample?.symbol ?? "arrow.up"
    }
    private var title: String {
        if route.hasArrived { return "已到达目的地附近" }
        if route.waitingAtStop { return "到达\(route.nextStop?.name ?? "途经点")附近" }
        if let message = route.guidanceLocationMessage { return message }
        guard let sample = route.guidanceSample else { return "沿校园道路前行" }
        if let distance = route.distanceToNextStop, distance <= sample.distanceToTurn + 1,
           let stop = route.nextStop {
            return "\(Int(ceil(distance))) 米后到达\(stop.name)附近"
        }
        return "\(max(0, Int(ceil(sample.distanceToTurn)))) 米后\(sample.instruction)"
    }
    private var subtitle: String {
        if route.waitingAtStop { return "取餐后点击“继续出发”" }
        if let stop = route.nextStop { return "下一站 · \(stop.name)" }
        return navigation.plan?.schedule?.location ?? navigation.plan?.destination?.name ?? "请留意实际道路情况"
    }
}
