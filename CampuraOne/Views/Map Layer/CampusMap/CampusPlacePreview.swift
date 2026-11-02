import SwiftUI
import CamapKit
import PetaKitUIX

struct CampusPlaceHeader: View {
    let placeID: String
    let onClose: () -> Void
    let openRoute: (RoutePreviewTarget) -> Void
    @ObservedObject private var map = CampusMapStore.shared
    private var place: Feature? { map.snapshot?.document.features.first { $0.id == placeID } }

    var body: some View {
        PreviewPanelHeader(title: place?.name ?? "校园地点", subtitle: "已发布校园地图",
                           showBack: false, onBack: {}, onClose: onClose) {
            if let place {
                Label("路线", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.subheadline.bold()).foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .beButton { openRoute(.place(id: place.id, name: place.name, frameID: place.frameId)) }
                    .accessibilityIdentifier("campus.place.route")
            }
        }
    }
}

struct CampusPlaceContent: View {
    let placeID: String
    @ObservedObject private var map = CampusMapStore.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let place = map.snapshot?.document.features.first(where: { $0.id == placeID }) {
                    Image(systemName: place.kind == "merchant" ? "storefront" : "building.2")
                        .font(.system(size: 50)).foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    if let description = place.description, !description.isEmpty { Text(description) }
                    if let hours = place.hours, !hours.isEmpty { Label(hours, systemImage: "clock") }
                    Text("路线终点以学校发布的可通行入口为准。")
                        .font(.caption).foregroundStyle(.secondary)
                } else { ContentUnavailableView("地点已更新", systemImage: "map", description: Text("请刷新校园地图后重新选择。")) }
            }.padding(20)
        }
    }
}
