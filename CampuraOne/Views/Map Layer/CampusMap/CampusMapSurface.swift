import SwiftUI
import MapKit
import CamapKit
import PetaKitUIX
import PetaToolKit

struct CampusMapSurface: View {
    @SwiftUI.Binding var cameraPosition: MapCameraPosition
    let location: CLLocation?
    let controlsTopInset: CGFloat
    let controlsHidden: Bool
    let navigationCameraMode: NavigationCameraMode
    let navigationCameraAvailable: Bool
    let toggleNavigationCamera: () -> Void
    var isActive = true
    var recenterNavigation: () -> Void = {}
    @ObservedObject private var browser = ContentBrowserStore.shared
    @ObservedObject private var map = CampusMapStore.shared
    @ObservedObject private var navigation = StudentNavigationStore.shared
    @ObservedObject private var routePreview = RoutePreviewStore.shared
    @State private var surfaceSize: CGSize = .zero
    @State private var isEditing = false
    @State private var dragAnchor: CGPoint?
    @State private var rotationAnchor: Double?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var cameraRevision = 0
    @State private var selectedFeatureID: String?
    @State private var turnCardHeight: CGFloat = 0
    @State private var turnCardFrame: CGRect = .zero
    @State private var surfaceFrame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var topClearance: CGFloat {
        let windowInset = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?.windows.first(where: \.isKeyWindow)?.safeAreaInsets.top ?? 0
        return max(controlsTopInset, max(0, windowInset - surfaceFrame.minY))
    }

    private var frame: SpatialFrame? {
        map.snapshot?.document.frames.first { $0.id == map.selectedFrameID }
    }
    private var isUncalibrated: Bool { frame.map { $0.bindings["mapkit"] == nil } ?? false }
    private var matchingPlan: NavigationPlan? {
        guard navigation.isCurrent, let plan = navigation.plan,
              map.snapshot?.hash == plan.mapHash else { return nil }
        return plan
    }
    private var previewedFeature: Feature? {
        guard let reference = browser.current?.reference else { return nil }
        let placeID: String?
        if case .place(let id) = reference { placeID = id }
        else { placeID = map.merchants.first(where: { $0.reference?.id == reference.id })?.placeID }
        return map.snapshot?.document.features.first { $0.id == placeID }
    }

    private var renderedPlan: NavigationPlan? {
        if map.displayMode == .original, isUncalibrated { return nil }
        return matchingPlan
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                    #if DEMO
                    if !routePreview.isPresented { UserAnnotation() }
                    #else
                    UserAnnotation()
                    #endif
                }
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
                                     plan: renderedPlan, suggestion: renderedPlan == nil ? nil : navigation.preview,
                                     location: location, isGuiding: navigation.isGuiding,
                                     projectionRevision: cameraRevision,
                                     screenPoint: { point, frameID in
                        coordinate(point, frameID: frameID).flatMap { proxy.convert($0, to: .local) }
                    }, locationPoint: { proxy.convert($0, to: .local) })
                }
                .overlay {
                    if routePreview.isSelectingOrigin, map.displayMode != .original || !isUncalibrated {
                        Canvas { context, _ in
                            for node in map.snapshot?.document.nodes ?? [] where node.frameId == map.selectedFrameID {
                                guard routePreview.originOptions.contains(where: { $0.id == node.id }),
                                      let coordinate = coordinate(node.position, frameID: node.frameId),
                                      let point = proxy.convert(coordinate, to: .local) else { continue }
                                let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                                context.fill(Path(ellipseIn: rect), with: .color(.accentColor))
                                context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 2)
                            }
                        }
                        .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .overlay { guidanceArrow(proxy: proxy) }
                .overlay(alignment: .top) {
                    NavigationTurnCard(route: routePreview)
                        .readSize { turnCardHeight = $0.height }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("campus.map.viewport")) } action: { frame in
                            let changedSize = turnCardFrame.size != frame.size
                            turnCardFrame = frame
                            if changedSize, navigation.isGuiding, !navigationCameraAvailable { fitPreviewRoute() }
                        }
                        .padding(.horizontal, 16).padding(.top, topClearance + 12)
                        .allowsHitTesting(false)
                }
                .simultaneousGesture(SpatialTapGesture().onEnded { value in
                    guard !isEditing, map.displayMode != .original || !isUncalibrated else { return }
                    if routePreview.isSelectingOrigin {
                        selectOrigin(at: value.location, proxy: proxy)
                    } else if routePreview.isPresented {
                        selectNotice(at: value.location, proxy: proxy)
                    } else {
                        selectFeature(at: value.location, proxy: proxy)
                    }
                })
                .overlay {
                    if !routePreview.isPresented, !isEditing, map.displayMode != .original || !isUncalibrated {
                        CampusMerchantMarkers(markers: map.merchantMarkers.filter { $0.frameID == map.selectedFrameID },
                                              projectionRevision: cameraRevision, selectedID: selectedFeatureID,
                                              screenPoint: { point, frameID in
                            coordinate(point, frameID: frameID).flatMap { proxy.convert($0, to: .local) }
                        })
                    }
                }
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
                            resetPlacement: { resetPlacement(); fitCampus() },
                            navigationCameraMode: navigationCameraMode,
                            navigationCameraAvailable: navigationCameraAvailable,
                            toggleNavigationCamera: toggleNavigationCamera,
                            recenterNavigation: recenterNavigation
                        )
                        .frame(maxWidth: min(220, geometry.size.width * 0.45), alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                        .padding(.top, topClearance + (navigation.isGuiding ? turnCardHeight + 20 : 12))
                    }
                    .opacity(controlsHidden ? 0 : 1)
                    .allowsHitTesting(!controlsHidden)
                }
        }
        .coordinateSpace(name: "campus.map.viewport")
        .onGeometryChange(for: CGSize.self) { $0.size } action: { surfaceSize = $0 }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { surfaceFrame = $0 }
        .onChange(of: routePreview.fitRequest) { _, _ in fitPreviewRoute() }
        .onChange(of: map.focusRequest?.id) { _, _ in fitFocusedFeatures() }
        .onChange(of: browser.current?.id) { _, _ in
            map.clearFocus()
            selectPreviewedContent()
        }
        .onChange(of: routePreview.isPresented) { _, shown in
            if !shown { selectPreviewedContent() }
        }
        .onChange(of: isActive) { _, active in
            if active, !routePreview.isPresented, map.focusRequest != nil { fitFocusedFeatures() }
        }
        .task(id: Int(routePreview.panelHeight / 4)) {
            guard routePreview.isPresented, !navigation.isGuiding, !cameraPosition.positionedByUser else { return }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, routePreview.isPresented, !navigation.isGuiding,
                  !cameraPosition.positionedByUser else { return }
            fitPreviewRoute()
        }
        .task(id: Int(browser.panelHeight / 4)) {
            guard browser.isPresented, !routePreview.isPresented, !cameraPosition.positionedByUser else { return }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, browser.isPresented, !routePreview.isPresented,
                  !cameraPosition.positionedByUser else { return }
            if map.focusRequest != nil { fitFocusedFeatures() }
            else { selectPreviewedContent() }
        }
        .onAppear { prepareMap(); selectPreviewedContent() }
        .onChange(of: map.revision) { _, _ in
            if let plan = navigation.plan, map.snapshot?.hash != plan.mapHash { navigation.invalidateContext() }
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
            if routePreview.isPresented, let id = routePreview.focusedOverlayID,
               renderedPlan?.overlays.first(where: { $0.id == id })?.frameId == map.selectedFrameID { fitPreviewRoute() }
            else if map.focusRequest != nil { fitFocusedFeatures() }
            else if previewedFeature?.frameId == map.selectedFrameID { selectPreviewedContent() }
        }
        .onChange(of: map.displayMode) { old, mode in
            if mode == .original { isEditing = false }
            if old == .original, mode != .original, isUncalibrated, routePreview.isPresented { fitPreviewRoute() }
        }
        .onChange(of: navigation.plan?.planID) { _, _ in
            if let routeFrame = navigation.plan?.route?.frameId { map.selectedFrameID = routeFrame }
        }
        .onChange(of: location) { _, location in routePreview.updateLocation(location) }
    }

    @ViewBuilder private func guidanceArrow(proxy: MapProxy) -> some View {
        if navigation.isGuiding, renderedPlan != nil,
           let sample = routePreview.guidanceSample,
           let frameID = renderedPlan?.route?.frameId,
           let position = coordinate(sample.position, frameID: frameID),
           let point = proxy.convert(position, to: .local),
           let ahead = coordinate(Point(sample.position.x + sample.forward.x, sample.position.y + sample.forward.y), frameID: frameID),
           let forward = proxy.convert(ahead, to: .local) {
            let angle = Double(atan2(forward.y - point.y, forward.x - point.x)) + Double.pi / 2
            Image(systemName: "location.north.fill")
                .font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                .padding(9).background(Color.accentColor, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.25), radius: 5)
                .rotationEffect(.radians(angle))
                .position(point).allowsHitTesting(false)
                .accessibilityLabel("导航位置")
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
        if matchingPlan?.hasRoute != true || frame?.bindings["mapkit"] == nil
            || matchingPlan?.route?.frameId != map.selectedFrameID {
            fitCampus()
        }
    }

    private func resetPlacement() {
        guard let frame, let document = map.snapshot?.document else { return }
        let center = visibleRegion?.center ?? location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        map.setPlacement(CampusMapGeometry.initialPlacement(
            frame: frame, points: CampusMapGeometry.points(in: document, frameID: frame.id),
            fallbackCenter: center), frameID: frame.id)
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

    private func fitPreviewRoute() {
        guard routePreview.isPresented, surfaceSize.height > 0 else { return }
        if routePreview.isSelectingOrigin {
            if map.displayMode == .original, isUncalibrated { map.displayMode = .drawing }
            let options = Set(routePreview.originOptions.map(\.id))
            let coordinates = (map.snapshot?.document.nodes ?? []).filter { options.contains($0.id) }
                .compactMap { coordinate($0.position, frameID: $0.frameId) }
            fitCoordinates(coordinates, panelHeight: routePreview.panelHeight)
            return
        }
        if let id = routePreview.focusedOverlayID, let overlay = renderedPlan?.overlays.first(where: { $0.id == id }) {
            guard overlay.frameId == map.selectedFrameID else { return }
            fitCoordinates(overlay.geometry.points.compactMap { coordinate($0, frameID: overlay.frameId) },
                           panelHeight: routePreview.panelHeight)
            return
        }
        guard renderedPlan != nil, let route = navigation.preview?.route ?? renderedPlan?.route,
              route.frameId == map.selectedFrameID else { return }
        let coordinates = route.polyline.compactMap { coordinate($0, frameID: route.frameId) }
        fitCoordinates(coordinates, panelHeight: routePreview.panelHeight)
    }

    private func fitCoordinates(_ coordinates: [CLLocationCoordinate2D], panelHeight: CGFloat, minimumMeters: Double = 80) {
        guard let rect = CampusMapViewport.fittingRect(coordinates: coordinates, size: surfaceSize,
            topInset: max(navigation.isGuiding ? turnCardFrame.maxY + 12 : topClearance, surfaceSize.height * 0.08),
            bottomInset: panelHeight + 12,
            minimumMeters: minimumMeters) else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { cameraPosition = .rect(rect) }
    }

    private func fitFocusedFeatures() {
        guard isActive, !routePreview.isPresented, let request = map.focusRequest,
              let document = map.snapshot?.document else { return }
        let features = document.features.filter { request.featureIDs.contains($0.id) && $0.frameId == map.selectedFrameID }
        let coordinates = features.flatMap { feature in
            feature.geometry.points.compactMap { coordinate($0, frameID: feature.frameId) }
        }
        selectedFeatureID = features.count == 1 ? features.first?.buildingId ?? features.first?.id : nil
        fitCoordinates(coordinates, panelHeight: browser.isPresented ? browser.panelHeight : 0, minimumMeters: 60)
    }

    private func selectPreviewedContent() {
        guard !routePreview.isPresented else { return }
        guard let feature = previewedFeature else {
            selectedFeatureID = nil; return
        }
        selectedFeatureID = feature.buildingId ?? feature.id
        guard isActive else { return }
        if map.selectedFrameID != feature.frameId { map.selectedFrameID = feature.frameId }
        fitCoordinates(feature.geometry.points.compactMap { coordinate($0, frameID: feature.frameId) },
                       panelHeight: browser.panelHeight, minimumMeters: 80)
    }

    private func selectOrigin(at point: CGPoint, proxy: MapProxy) {
        guard let document = map.snapshot?.document else { return }
        let options = Dictionary(uniqueKeysWithValues: routePreview.originOptions.map { ($0.id, $0) })
        let option = document.nodes.compactMap { node -> (RoutePreviewStore.OriginOption, CGFloat)? in
            guard let option = options[node.id],
                  let coordinate = coordinate(node.position, frameID: node.frameId),
                  let screen = proxy.convert(coordinate, to: .local) else { return nil }
            let distance = hypot(screen.x - point.x, screen.y - point.y)
            return distance <= 35 ? (option, distance) : nil
        }.min { $0.1 < $1.1 }?.0
        if let option { Task { await routePreview.selectOrigin(option) } }
    }

    private func selectNotice(at point: CGPoint, proxy: MapProxy) {
        guard let plan = matchingPlan else { return }
        let overlay = plan.overlays.first { overlay in
            guard let coordinate = coordinate(CampusMapGeometry.center(of: overlay.geometry.points), frameID: overlay.frameId),
                  let screen = proxy.convert(coordinate, to: .local) else { return false }
            return hypot(screen.x - point.x, screen.y - point.y) <= 40
        }
        if let overlay, let source = plan.sources.first(where: { $0.announceID == overlay.sourceID && $0.version == overlay.sourceVersion }) {
            routePreview.selectedSource = source
            Task { await navigation.loadSource(source) }
        }
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
        let candidates = document.features.filter {
            $0.frameId == frame.id && $0.levelId == nil
        }.compactMap { feature -> (Feature, CGFloat)? in
            let position = CampusMapGeometry.center(of: feature.geometry.points)
            guard let coordinate = coordinate(position, frameID: frame.id),
                  let p = proxy.convert(coordinate, to: .local) else { return nil }
            let distance = hypot(p.x - point.x, p.y - point.y)
            return distance < 35 ? (feature, distance) : nil
        }
        // A nearby shop marker wins over its containing building's label.
        let shop = candidates.filter { $0.0.kind == "merchant" && $0.1 < 24 }.min { $0.1 < $1.1 }
        let containingBuilding = document.features.first { feature in
            guard feature.frameId == frame.id, feature.kind == "building", feature.levelId == nil,
                  case .polygon(let points) = feature.geometry else { return false }
            let screens = points.compactMap { local in
                coordinate(local, frameID: frame.id).flatMap { proxy.convert($0, to: .local) }
            }
            guard screens.count == points.count, let first = screens.first else { return false }
            let path = CGMutablePath()
            path.move(to: first)
            for screen in screens.dropFirst() { path.addLine(to: screen) }
            path.closeSubpath()
            return path.contains(point)
        }
        selectedFeatureID = shop?.0.id ?? containingBuilding?.id ?? candidates.min { $0.1 < $1.1 }?.0.id
        if let selectedFeatureID {
            let reference = map.merchant(at: selectedFeatureID)?.reference ?? .place(selectedFeatureID)
            ContentBrowserStore.shared.open(reference)
        }
    }

}
