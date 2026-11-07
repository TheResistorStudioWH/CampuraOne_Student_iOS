import SwiftUI
import CamapKit
import PetaKitUIX

extension Feature {
    var campusSymbol: String {
        switch kind {
        case "merchant": return "storefront.fill"
        case "gate", "door": return "door.left.hand.open"
        case "building": return "building.2.fill"
        default: return "mappin.and.ellipse"
        }
    }

    var campusKindTitle: String {
        switch kind {
        case "merchant": return "商户"
        case "gate", "door": return "出入口"
        case "building": return "校园建筑"
        default: return "校园地点"
        }
    }

    var campusDisplayName: String { name.isEmpty || name == "建筑" ? campusKindTitle : name }
}

struct CampusPlaceHeader: View {
    let placeID: String
    @ObservedObject var browser: ContentBrowserStore
    let onClose: () -> Void
    let openRoute: (RoutePreviewTarget) -> Void
    @ObservedObject private var map = CampusMapStore.shared
    private var place: Feature? { map.snapshot?.document.features.first { $0.id == placeID } }

    var body: some View {
        PreviewPanelHeader(title: place?.campusDisplayName ?? "校园地点", subtitle: subtitle,
                           showBack: browser.pages.count > 1, onBack: browser.back, onClose: onClose) {
            if let place {
                HStack(spacing: 10) {
                    MapPanelAction(title: "路线", symbol: "arrow.triangle.turn.up.right.diamond.fill", prominent: true) {
                        openRoute(.place(id: place.id, name: place.campusDisplayName, frameID: place.frameId))
                    }
                    .accessibilityIdentifier("campus.place.route")
                    MapPanelIconButton(title: "在地图上查看地点", symbol: "scope", tint: .accentColor) {
                        map.focus(on: [place.id])
                    }
                    .accessibilityIdentifier("campus.place.focus")
                }
            }
        }
    }

    private var subtitle: String? {
        guard let place else { return nil }
        let count = map.merchants.filter { $0.placeID == place.id || $0.mapLocation.buildingId == place.id }.count
        if place.campusDisplayName == place.campusKindTitle { return count > 0 ? "\(count) 家商户" : nil }
        return count > 0 ? "\(place.campusKindTitle) · \(count) 家商户" : place.campusKindTitle
    }
}

struct CampusPlaceContent: View {
    let placeID: String
    @ObservedObject var page: ContentPreviewPage
    @ObservedObject var browser: ContentBrowserStore
    @ObservedObject private var map = CampusMapStore.shared
    private var query: String { page.placeQuery }

    private var place: Feature? { map.snapshot?.document.features.first { $0.id == placeID } }
    private var merchants: [CampusMerchantBindings.Entry] {
        map.merchants.filter { $0.placeID == placeID || $0.mapLocation.buildingId == placeID }
    }
    private func feature(for entry: CampusMerchantBindings.Entry) -> Feature? {
        map.snapshot?.document.features.first { $0.id == entry.placeID }
    }
    private var levels: [BuildingLevel] {
        let ids = Set(merchants.compactMap { $0.mapLocation.levelId })
        return (place?.levels ?? []).filter { ids.contains($0.id) }.sorted { $0.ordinal < $1.ordinal }
    }
    private var filteredMerchants: [CampusMerchantBindings.Entry] {
        merchants.filter { entry in
            (page.placeLevelID == nil || entry.mapLocation.levelId == page.placeLevelID)
                && (query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || feature(for: entry)?.name.localizedStandardContains(query.trimmingCharacters(in: .whitespacesAndNewlines)) == true)
        }.sorted { a, b in
            let orderA = levels.firstIndex { $0.id == a.mapLocation.levelId } ?? Int.max
            let orderB = levels.firstIndex { $0.id == b.mapLocation.levelId } ?? Int.max
            if orderA != orderB { return orderA < orderB }
            return (feature(for: a)?.name ?? "").localizedStandardCompare(feature(for: b)?.name ?? "") == .orderedAscending
        }
    }

    private var merchantListTitle: String {
        if place?.kind == "merchant" { return "商家资料" }
        if let floor = levels.first(where: { $0.id == page.placeLevelID }) { return "\(floor.label) 商家" }
        return "楼内商家"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let place {
                    placeInformation(place).id("place-info")
                    if !merchants.isEmpty {
                        HStack(alignment: .firstTextBaseline) {
                            Text(merchantListTitle).font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            Text("\(filteredMerchants.count) 家").font(.subheadline).foregroundStyle(.secondary)
                        }.id("merchants")
                        if merchants.count > 6 { MapPanelSearchField(prompt: "查找这里的商家", text: $page.placeQuery).id("merchant-search") }
                        if levels.count > 1 { floorPicker.id("floors") }
                        if filteredMerchants.isEmpty {
                            MapPanelMessage(title: "没有找到匹配商家", message: "试试其他名称或楼层。", symbol: "magnifyingglass")
                                .id("merchant-empty")
                        }
                        ForEach(filteredMerchants) { entry in
                            if let feature = feature(for: entry), let reference = entry.reference {
                                merchantRow(feature, reference: reference).id("merchant-\(entry.id)")
                            }
                        }
                    } else if map.isLoading {
                        ProgressView("正在读取商家资料…").frame(maxWidth: .infinity, minHeight: 80)
                    } else if let error = map.merchantError {
                        MapPanelMessage(title: "商家资料暂不可用", message: error, symbol: "wifi.exclamationmark", tint: .orange)
                        MapPanelAction(title: "重新读取", symbol: "arrow.clockwise") { Task { await map.reload() } }
                    }
                    Label("请以现场出入口和学校最新通行安排为准。", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        .id("place-note")
                } else {
                    MapPanelMessage(title: "地点已更新", message: "刷新校园地图后，可以重新选择这个地点。", symbol: "map")
                    MapPanelAction(title: "刷新地图", symbol: "arrow.clockwise") { Task { await map.reload() } }
                }
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $page.scrollID, anchor: .top)
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.automatic)
        .task { await map.loadIfNeeded() }
        .onChange(of: page.placeLevelID) { _, _ in page.scrollID = "floors" }
        .onChange(of: page.placeQuery) { _, _ in page.scrollID = "merchant-search" }
        .onChange(of: map.revision) { _, _ in
            if let id = page.placeLevelID, !levels.contains(where: { $0.id == id }) { page.placeLevelID = nil }
        }
    }

    private func placeInformation(_ place: Feature) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: place.campusSymbol)
                    .font(.title2).foregroundStyle(Color.accentColor)
                    .frame(width: 46, height: 46)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(place.kind == "building" && place.levels?.isEmpty == false ? "楼层" : place.campusKindTitle)
                        .font(.subheadline.weight(.semibold))
                    if let buildingID = place.buildingId,
                       let building = map.snapshot?.document.features.first(where: { $0.id == buildingID }) {
                        Text(building.campusDisplayName).font(.subheadline).foregroundStyle(.secondary)
                        if let level = building.levels?.first(where: { $0.id == place.levelId }) {
                            Text(level.label).font(.caption).foregroundStyle(.secondary)
                        }
                    } else if let available = place.levels, !available.isEmpty {
                        Text(available.sorted { $0.ordinal < $1.ordinal }.map(\.label).joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if let description = place.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(description).font(.subheadline).textSelection(.enabled)
            }
            if let hours = place.hours, !hours.isEmpty {
                Label(hours, systemImage: "clock").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .mapPanelCard()
    }

    private var floorPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                floorButton("全部楼层", id: nil)
                ForEach(levels, id: \.id) { floor in floorButton(floor.label, id: floor.id) }
            }
        }.scrollIndicators(.hidden)
    }

    private func floorButton(_ title: String, id: String?) -> some View {
        Text(title).font(.subheadline.weight(.semibold))
            .foregroundStyle(page.placeLevelID == id ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 14).frame(minHeight: 44)
            .background(Color.accentColor.opacity(page.placeLevelID == id ? 0.13 : 0.04), in: Capsule())
            .contentShape(Capsule())
            .beButton { page.placeLevelID = id }
            .buttonStyle(.plain)
            .accessibilityAddTraits(page.placeLevelID == id ? .isSelected : [])
    }

    private func merchantAccessibilityID(_ reference: CampusContentReference) -> String {
        switch reference {
        case .mainShop(let id): return "campus.place.merchant.main.\(id)"
        case .subShop(let id, _): return "campus.place.merchant.sub.\(id)"
        default: return "campus.place.merchant.\(reference.id)"
        }
    }

    private func merchantRow(_ feature: Feature, reference: CampusContentReference) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront.fill").foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let level = place?.levels?.first(where: { $0.id == feature.levelId }) {
                    Text(level.label).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .beButton { browser.push(reference) }
        .buttonStyle(.plain)
        .accessibilityIdentifier(merchantAccessibilityID(reference))
    }
}

/// Clustering is only presentational. Each menu opens an explicitly associated
/// building/shop, and "zoom" fits those real features rather than guessing a place.
struct CampusMerchantMarkers: View {
    let markers: [CampusMapStore.MerchantMarker]
    let projectionRevision: Int
    let selectedID: String?
    let screenPoint: (Point, String) -> CGPoint?
    @ObservedObject private var map = CampusMapStore.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size).insetBy(dx: -30, dy: -30)
            let projected = markers.compactMap { marker -> CampusMarkerLayout.Item? in
                guard let point = screenPoint(marker.point, marker.frameID), bounds.contains(point) else { return nil }
                return .init(id: marker.id, point: point)
            }
            let clusters = CampusMarkerLayout.clusters(projected, separation: typeSize.isAccessibilitySize ? 78 : 64)
            ForEach(clusters) { cluster in
                let members = markers.filter { marker in cluster.items.contains { $0.id == marker.id } }
                let selected = members.contains { $0.id == selectedID }
                let labelFits = selected || !clusters.contains { other in
                    other.id != cluster.id && abs(other.center.x - cluster.center.x) < 120 && abs(other.center.y - cluster.center.y) < 58
                }
                Group {
                    if let first = members.first, members.count == 1 {
                        markerLabel(members, selected: selected, showTitle: labelFits)
                            .beButton { ContentBrowserStore.shared.open(first.reference) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("查看商户：\(first.title)")
                            .accessibilityIdentifier("campus.merchant.\(first.id)")
                    } else {
                        Menu {
                            Label("放大查看这片区域", systemImage: "plus.magnifyingglass")
                                .beButton { map.focus(on: members.map(\.id)) }
                            Divider()
                            ForEach(members) { member in
                                Label(member.title, systemImage: "building.2")
                                    .beButton { ContentBrowserStore.shared.open(member.reference) }
                            }
                        } label: { markerLabel(members, selected: selected, showTitle: labelFits) }
                        .accessibilityLabel("附近 \(members.reduce(0) { $0 + $1.count }) 家商户")
                        .accessibilityHint("选择一栋建筑查看商家，或放大这片区域")
                        .accessibilityIdentifier("campus.merchant.cluster.\(cluster.id)")
                    }
                }
                .position(cluster.center)
                .zIndex(selected ? 1 : 0)
            }
        }
    }

    private func markerLabel(_ members: [CampusMapStore.MerchantMarker], selected: Bool, showTitle: Bool) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "storefront.fill")
                Text("\(members.reduce(0) { $0 + $1.count })").monospacedDigit()
                if members.count > 1 { Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)) }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(selected ? Color.white : Color.accentColor)
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background {
                if selected { Capsule().fill(Color.accentColor) }
                else if reduceTransparency { Capsule().fill(Color(uiColor: .secondarySystemBackground)) }
                else { Capsule().fill(.regularMaterial) }
            }
            .overlay { Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1) }
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            if showTitle {
                Text(members.count == 1 ? (members.first?.title ?? "") : "附近商户")
                    .font(.caption2.weight(.semibold)).lineLimit(1)
                    .frame(maxWidth: 120)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .fixedSize()
        .contentShape(Rectangle())
    }
}
