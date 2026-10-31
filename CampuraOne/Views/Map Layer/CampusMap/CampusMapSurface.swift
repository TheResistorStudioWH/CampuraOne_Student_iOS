import SwiftUI
import MapKit
import CamapKit
import PetaKitUIX

struct CampusMapSurface: View {
    @SwiftUI.Binding var cameraPosition: MapCameraPosition
    let location: CLLocation?
    let controlsTopInset: CGFloat
    let controlsHidden: Bool
    @ObservedObject private var map = CampusMapStore.shared
    @ObservedObject private var navigation = StudentNavigationStore.shared
    @State private var isEditing = false
    @State private var dragAnchor: CGPoint?
    @State private var rotationAnchor: Double?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var cameraRevision = 0
    @State private var selectedFeatureID: String?
    @State private var lastSentLocation: CLLocation?

    private var frame: SpatialFrame? {
        map.snapshot?.document.frames.first { $0.id == map.selectedFrameID }
    }
    private var isUncalibrated: Bool { frame.map { $0.bindings["mapkit"] == nil } ?? false }
    private var matchingPlan: NavigationPlan? {
        guard navigation.isCurrent, let plan = navigation.plan,
              map.snapshot?.hash == plan.mapHash else { return nil }
        return plan
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) { UserAnnotation() }
                .ignoresSafeArea(.keyboard)
                .mapStyle(.standard(elevation: .realistic))
                .mapControls { MapCompass(); MapScaleView(); MapPitchToggle() }
                .onMapCameraChange(frequency: .continuous) { context in
                    visibleRegion = context.region
                    cameraRevision &+= 1
                }
                .overlay {
                    CampusMapDrawing(document: map.snapshot?.document, frameID: map.selectedFrameID,
                                     mode: map.displayMode, selectedFeatureID: selectedFeatureID,
                                     plan: matchingPlan, suggestion: matchingPlan == nil ? nil : navigation.preview,
                                     location: location,
                                     projectionRevision: cameraRevision,
                                     screenPoint: { point, frameID in
                        coordinate(point, frameID: frameID).flatMap { proxy.convert($0, to: .local) }
                    }, locationPoint: { proxy.convert($0, to: .local) })
                }
                .simultaneousGesture(SpatialTapGesture().onEnded { value in
                    guard !isEditing, map.displayMode != .original else { return }
                    selectFeature(at: value.location, proxy: proxy)
                })
                .overlay {
                    if isEditing {
                        Color.clear.contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 3)
                                .onChanged { value in moveDrawing(value, proxy: proxy) }
                                .onEnded { _ in dragAnchor = nil })
                            .simultaneousGesture(RotationGesture()
                                .onChanged { value in rotateDrawing(value) }
                                .onEnded { _ in rotationAnchor = nil })
                            .accessibilityLabel("临时摆放校园图")
                            .accessibilityHint("单指移动，双指旋转；此位置不用于定位")
                    }
                }
                .overlay(alignment: .topTrailing) {
                    GeometryReader { geometry in
                        CampusMapControls(
                            mode: $map.displayMode, selectedFrameID: $map.selectedFrameID,
                            frames: map.snapshot?.document.frames.map { .init(id: $0.id, name: $0.name) } ?? [],
                            isUncalibrated: isUncalibrated, isEditing: isEditing,
                            toggleEditing: { isEditing.toggle() },
                            resetPlacement: { resetPlacement(); fitCampus() }
                        )
                        .frame(maxWidth: min(220, geometry.size.width * 0.45), alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                        .padding(.top, controlsTopInset + 12)
                    }
                    .opacity(controlsHidden ? 0 : 1)
                    .allowsHitTesting(!controlsHidden)
                }
        }
        .onAppear { prepareMap() }
        .onChange(of: map.revision) { _, _ in
            isEditing = false
            selectedFeatureID = nil
            prepareMap()
        }
        .onChange(of: map.selectedFrameID) { _, _ in
            isEditing = false
            selectedFeatureID = nil
            dragAnchor = nil
            rotationAnchor = nil
            prepareMap()
        }
        .onChange(of: map.displayMode) { _, mode in if mode == .original { isEditing = false } }
        .onChange(of: navigation.plan?.planID) { _, _ in
            if let routeFrame = navigation.plan?.route?.frameId { map.selectedFrameID = routeFrame }
        }
        .onChange(of: location) { _, location in
            guard let location, let frame,
                  let origin = CampusMapGeometry.gpsOrigin(location, frame: frame),
                  lastSentLocation.map({ location.distance(from: $0) >= 20 }) ?? true else { return }
            guard navigation.plan != nil, !navigation.isWorking else { return }
            lastSentLocation = location
            Task { await navigation.updateLocation(origin) }
        }
    }

    private func coordinate(_ point: Point, frameID: String) -> CLLocationCoordinate2D? {
        guard let frame = map.snapshot?.document.frames.first(where: { $0.id == frameID }) else { return nil }
        return CampusMapGeometry.coordinate(point, frame: frame, temporary: map.placements[frameID])
    }

    private func prepareMap() {
        guard let document = map.snapshot?.document else { return }
        if frame == nil { map.selectedFrameID = document.frames.first?.id; return }
        if isUncalibrated, let frame, map.placements[frame.id] == nil { resetPlacement() }
        fitCampus()
    }

    private func resetPlacement() {
        guard let frame, let document = map.snapshot?.document else { return }
        let center = visibleRegion?.center ?? location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        map.setPlacement(.init(longitude: center.longitude, latitude: center.latitude,
                               localAnchor: CampusMapGeometry.center(of: CampusMapGeometry.points(in: document, frameID: frame.id))),
                         frameID: frame.id)
    }

    private func fitCampus() {
        guard let frame, let document = map.snapshot?.document else { return }
        let coordinates = CampusMapGeometry.points(in: document, frameID: frame.id)
            .compactMap { coordinate($0, frameID: frame.id) }
        guard let first = coordinates.first else { return }
        let minLat = coordinates.map(\.latitude).min()!, maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!, maxLon = coordinates.map(\.longitude).max()!
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.0015, (maxLat - minLat) * 1.6),
                                   longitudeDelta: max(0.0015, (maxLon - minLon) * 1.6)))
        guard CLLocationCoordinate2DIsValid(first) else { return }
        cameraPosition = .region(region)
    }

    private func moveDrawing(_ value: DragGesture.Value, proxy: MapProxy) {
        guard let frame, var placement = map.placements[frame.id] else { return }
        if dragAnchor == nil {
            dragAnchor = proxy.convert(CLLocationCoordinate2D(latitude: placement.latitude, longitude: placement.longitude), to: .local)
        }
        guard let anchor = dragAnchor,
              let point = proxy.convert(CGPoint(x: anchor.x + value.translation.width, y: anchor.y + value.translation.height), from: .local) else { return }
        placement.longitude = point.longitude
        placement.latitude = point.latitude
        map.setPlacement(placement, frameID: frame.id)
    }

    private func rotateDrawing(_ angle: Angle) {
        guard let frame, var placement = map.placements[frame.id] else { return }
        if rotationAnchor == nil { rotationAnchor = placement.rotation }
        placement.rotation = (rotationAnchor ?? 0) - angle.degrees
        map.setPlacement(placement, frameID: frame.id)
    }

    private func selectFeature(at point: CGPoint, proxy: MapProxy) {
        guard let frame, let document = map.snapshot?.document else { return }
        selectedFeatureID = document.features.filter { $0.frameId == frame.id && $0.levelId == nil }
            .compactMap { feature -> (String, CGFloat)? in
                let position = CampusMapGeometry.center(of: feature.geometry.points)
                guard let coordinate = coordinate(position, frameID: frame.id),
                      let p = proxy.convert(coordinate, to: .local) else { return nil }
                let distance = hypot(p.x - point.x, p.y - point.y)
                return distance < 35 ? (feature.id, distance) : nil
            }.min(by: { $0.1 < $1.1 })?.0
    }

}
