import Foundation
import Combine
import CoreLocation
import CamapKit

@MainActor
final class RoutePreviewStore: ObservableObject {
    struct OriginOption: Identifiable {
        let id: String
        let name: String
        let frameID: String
        var origin: NavigationOrigin { .node(id: id, frameID: frameID) }
    }
    @Published private(set) var target: RoutePreviewTarget?
    @Published private(set) var origin: NavigationOrigin?
    @Published private(set) var originName = "当前位置"
    @Published var isSelectingOrigin = false
    @Published var selectedSource: NavigationSource?
    @Published private(set) var fitRequest = UUID()
    @Published private(set) var overviewRequest = UUID()
    @Published var panelHeight: Double = 0
    @Published private(set) var preparationError: String?
    @Published private(set) var isCalculating = false
    private var latestLocation: CLLocation?
    private var userID: Int?
    private var generation = UUID()
    private var resolvedDestination: String?
    private let navigation: StudentNavigationStore
    private let map: CampusMapStore
    var isPresented: Bool { target != nil }
    var requestID: UUID { generation }

    init(navigation: StudentNavigationStore, map: CampusMapStore) { self.navigation = navigation; self.map = map }

    func bind(userID: Int?) {
        guard self.userID != userID else { return }
        close(); self.userID = userID; latestLocation = nil
    }

    func updateLocation(_ location: CLLocation?) { latestLocation = location }

    private var currentGPSOrigin: NavigationOrigin? {
        guard let location = latestLocation,
              let frame = map.snapshot?.document.frames.first(where: { $0.id == (target?.frameID ?? map.selectedFrameID) }) else { return nil }
        return CampusMapGeometry.gpsOrigin(location, frame: frame)
    }
    var canUseCurrentLocation: Bool { currentGPSOrigin != nil }

    func useCurrentLocation() async {
        guard let gps = currentGPSOrigin else { return }
        origin = gps; originName = "当前位置"; isSelectingOrigin = false
        await calculate()
    }

    func open(_ target: RoutePreviewTarget) {
        guard userID != nil else { return }
        close()
        self.target = target
        resolvedDestination = target.destination
    }

    func prepare() async {
        guard let userID, target != nil else { return }
        let ticket = generation
        await map.load(userID: userID)
        // MapView may already own the initial fetch. Its store deliberately
        // returns early for duplicate loads; wait for that result here.
        while map.isLoading, ticket == generation, !Task.isCancelled {
            do { try await Task.sleep(for: .milliseconds(50)) }
            catch { return }
        }
        guard ticket == generation else { return }
        guard map.snapshot != nil else { preparationError = map.errorMessage ?? "学校尚未发布校园地图"; return }
        if let gps = currentGPSOrigin {
            origin = gps; originName = "当前位置"
            await calculate()
        } else { isSelectingOrigin = true }
    }

    var originOptions: [OriginOption] {
        guard let document = map.snapshot?.document else { return [] }
        let connected = Set(document.edges.filter { !$0.closed }.flatMap { [$0.from, $0.to] })
        return document.nodes.filter { connected.contains($0.id) }.map { node in
            let frame = document.frames.first { $0.id == node.frameId }
            return OriginOption(id: node.id, name: "\(node.name.isEmpty ? "校园路点" : node.name) · \(frame?.name ?? "校园")", frameID: node.frameId)
        }
    }

    func selectOrigin(_ option: OriginOption) async {
        origin = option.origin; originName = "所选起点：\(option.name)"
        isSelectingOrigin = false
        await calculate()
    }

    func chooseDestination(_ place: NavigationPlace) async {
        resolvedDestination = place.placeID
        await calculate()
    }

    func calculate() async {
        guard let origin, target != nil, !navigation.isWorking, !isCalculating else { return }
        let ticket = generation
        isCalculating = true
        defer { if ticket == generation { isCalculating = false } }
        preparationError = nil
        if navigation.plan == nil || navigation.requiresRestart {
            navigation.discardPreview()
            await navigation.startPreview(origin: origin, destination: resolvedDestination)
        } else if navigation.requiresReplan {
            await navigation.replan(origin: origin, destination: resolvedDestination)
        } else {
            await navigation.update(origin: origin, destination: resolvedDestination)
        }
        guard ticket == generation else { return }
        if navigation.plan?.resolutionReason == "choose_start_on_published_network"
            || navigation.plan?.resolutionReason?.contains("origin") == true { isSelectingOrigin = true }
        if let frame = navigation.plan?.route?.frameId { map.selectedFrameID = frame }
        fitRequest = UUID()
    }

    func fitRoute() { overviewRequest = UUID(); fitRequest = UUID() }

    func close() {
        generation = UUID()
        target = nil; origin = nil; resolvedDestination = nil
        isSelectingOrigin = false; selectedSource = nil; panelHeight = 0; preparationError = nil; isCalculating = false
        navigation.discardPreview()
    }
}
