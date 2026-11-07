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
    @Published private(set) var mapBrowsingRequest = UUID()
    @Published private(set) var focusedOverlayID: String?
    @Published var panelHeight: Double = 0
    @Published private(set) var preparationError: String?
    @Published private(set) var isCalculating = false
    @Published private(set) var guidanceDistance = 0.0
    @Published private(set) var isPlaying = false
    @Published private(set) var waitingAtStop = false
    @Published private(set) var completedStops = 0
    @Published private(set) var guidanceLocationMessage: String?
    private var playbackTask: Task<Void, Never>?
    private var guidancePlanID: String?
    var isGuiding: Bool { navigation.isGuiding }
    var guidanceGeometry: NavigationGuidanceGeometry { .init(points: navigation.plan?.route?.polyline ?? []) }
    var guidanceSample: NavigationGuidanceGeometry.Sample? { guidanceGeometry.sample(at: guidanceDistance) }
    private var arrivalTolerance: Double {
        #if DEMO
        0.5
        #else
        10
        #endif
    }
    var hasArrived: Bool { isGuiding && nextStop == nil && guidanceDistance >= guidanceGeometry.total - arrivalTolerance }
    var distanceToNextStop: Double? { nextStopDistance.map { max(0, $0 - guidanceDistance) } }
    var nextStop: NavigationStop? {
        guard let stops = navigation.plan?.waypoints, completedStops < stops.count else { return nil }
        return stops[completedStops]
    }
    private var nextStopDistance: Double? {
        guard nextStop != nil, let legs = navigation.plan?.route?.legs, completedStops < legs.count else { return nil }
        return legs.prefix(completedStops + 1).reduce(0) { $0 + NavigationGuidanceGeometry(points: $1.polyline).total }
    }
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

    func updateLocation(_ location: CLLocation?) {
        latestLocation = location
        #if !DEMO
        guard isGuiding, !waitingAtStop else { return }
        guard let location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 35,
              abs(location.timestamp.timeIntervalSinceNow) < 30,
              let frame = map.snapshot?.document.frames.first(where: { $0.id == navigation.plan?.route?.frameId }),
              CampusMapGeometry.gpsOrigin(location, frame: frame) != nil,
              let binding = frame.bindings["mapkit"] else {
            guidanceLocationMessage = "等待准确定位…"; return
        }
        let point = binding.unproject(Point(location.coordinate.longitude, location.coordinate.latitude))
        if guidancePlanID != navigation.plan?.planID { guidanceDistance = 0; guidancePlanID = navigation.plan?.planID }
        guard let projection = guidanceGeometry.projectedProgress(of: point, after: guidanceDistance), projection.distance <= 35 else {
            guidanceLocationMessage = "已偏离路线，请重新规划"; return
        }
        guidanceLocationMessage = nil
        advanceGuidance(to: max(guidanceDistance, projection.progress))
        #endif
    }

    func startGuidance() {
        guard navigation.isCurrent, navigation.plan?.hasRoute == true, !navigation.isWorking,
              navigation.plan?.mapHash == map.snapshot?.hash else { return }
        stopGuidance()
        navigation.beginGuidance()
        guidancePlanID = navigation.plan?.planID
        guidanceDistance = 0; completedStops = 0; waitingAtStop = false
        #if DEMO
        play()
        #else
        guidanceLocationMessage = "等待准确定位…"
        updateLocation(latestLocation)
        #endif
        fitRoute()
    }

    func stopGuidance() {
        playbackTask?.cancel(); playbackTask = nil; isPlaying = false
        guidanceDistance = 0; completedStops = 0; waitingAtStop = false; guidanceLocationMessage = nil
        if navigation.isGuiding { navigation.returnToPreview() }
    }

    func continueFromStop() {
        guard waitingAtStop else { return }
        completedStops += 1; waitingAtStop = false
        #if DEMO
        play()
        #endif
    }

    private func advanceGuidance(to distance: Double) {
        if let stopDistance = nextStopDistance, distance >= stopDistance - arrivalTolerance {
            guidanceDistance = stopDistance; waitingAtStop = true; pausePlayback(); return
        }
        guidanceDistance = min(guidanceGeometry.total, max(0, distance))
        if hasArrived { pausePlayback() }
    }

    func pausePlayback() { playbackTask?.cancel(); playbackTask = nil; isPlaying = false }

    #if DEMO
    func play() {
        guard isGuiding, !hasArrived, !waitingAtStop, !isPlaying else { return }
        isPlaying = true
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard let self, self.isGuiding, self.isPlaying else { return }
                // Accelerated local playback, independent of the phone's GPS.
                self.advanceGuidance(to: self.guidanceDistance + 1.2)
            }
        }
    }
    func nextGuidanceStep() {
        pausePlayback()
        if waitingAtStop { continueFromStop(); pausePlayback(); return }
        advanceGuidance(to: guidanceGeometry.nextVertex(after: guidanceDistance))
    }
    #endif

    private var currentGPSOrigin: NavigationOrigin? {
        #if DEMO
        return nil
        #else
        guard let location = latestLocation,
              let frame = map.snapshot?.document.frames.first(where: { $0.id == (target?.frameID ?? map.selectedFrameID) }) else { return nil }
        return CampusMapGeometry.gpsOrigin(location, frame: frame)
        #endif
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
        preparationError = nil
        let ticket = generation
        await map.load(userID: userID)
        // MapView may already own the initial fetch. Its store deliberately
        // returns early for duplicate loads; wait for that result here.
        while map.isLoading, ticket == generation, !Task.isCancelled {
            do { try await Task.sleep(for: .milliseconds(50)) }
            catch { return }
        }
        guard ticket == generation, !Task.isCancelled else { return }
        guard map.snapshot != nil else { preparationError = map.errorMessage ?? "学校尚未发布校园地图"; return }
        if let gps = currentGPSOrigin {
            origin = gps; originName = "当前位置"
            await calculate()
        } else {
            #if DEMO
            if let option = originOptions.first { await selectOrigin(option) }
            else { isSelectingOrigin = true }
            #else
            isSelectingOrigin = true
            #endif
        }
    }

    var originOptions: [OriginOption] {
        guard let document = map.snapshot?.document else { return [] }
        #if DEMO
        guard let node = document.nodes.first(where: { $0.id == PreviewNavigation.startID }) else { return [] }
        return [OriginOption(id: node.id, name: "学生宿舍17栋附近", frameID: node.frameId)]
        #else
        let connected = Set(document.edges.filter { !$0.closed }.flatMap { [$0.from, $0.to] })
        return document.nodes.filter { connected.contains($0.id) }.map { node in
            let frame = document.frames.first { $0.id == node.frameId }
            return OriginOption(id: node.id, name: "\(node.name.isEmpty ? "校园路点" : node.name) · \(frame?.name ?? "校园")", frameID: node.frameId)
        }
        #endif
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
        stopGuidance()
        let ticket = generation
        focusedOverlayID = nil
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

    func showOverview() {
        mapBrowsingRequest = UUID()
        fitRoute()
    }

    func focusOverlay(_ id: String) {
        guard navigation.isCurrent, let overlay = navigation.plan?.overlays.first(where: { $0.id == id }),
              map.snapshot?.document.frames.contains(where: { $0.id == overlay.frameId }) == true else { return }
        map.selectedFrameID = overlay.frameId
        focusedOverlayID = id
        mapBrowsingRequest = UUID()
        overviewRequest = UUID()
        fitRequest = UUID()
    }

    func refreshRouteFit() {
        if let id = focusedOverlayID, navigation.plan?.overlays.contains(where: { $0.id == id }) != true { focusedOverlayID = nil }
        fitRequest = UUID()
    }
    func fitRoute() {
        focusedOverlayID = nil
        if let frameID = navigation.plan?.route?.frameId, map.snapshot?.document.frames.contains(where: { $0.id == frameID }) == true {
            map.selectedFrameID = frameID
        }
        overviewRequest = UUID(); fitRequest = UUID()
    }

    func close() {
        stopGuidance()
        generation = UUID()
        target = nil; origin = nil; resolvedDestination = nil; focusedOverlayID = nil
        isSelectingOrigin = false; selectedSource = nil; panelHeight = 0; preparationError = nil; isCalculating = false
        navigation.discardPreview()
    }
}
