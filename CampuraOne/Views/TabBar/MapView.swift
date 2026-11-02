//
//  MapView.swift
//  CampuraOne
//
//  Created by LShayc1own on 20/05/2026.
//

import SwiftUI
import PetaToolKit
import PetaKitUIX
import SwiftData
import MapKit
import CoreLocation
import Combine
import CamapKit

#Preview("app - 已登录") {
    PreviewAppView()
}

@MainActor
final class MapLocationManager: NSObject, ObservableObject {
    @Published private(set) var location: CLLocation?
    @Published private(set) var heading: CLHeading?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var accuracyAuthorization: CLAccuracyAuthorization
    @Published private(set) var locationError: String?
    
    private let manager = CLLocationManager()
    private var wantsHeading = false
    
    override init() {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        
        super.init()
        
        manager.delegate = self
        //请求较高精度的位置
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 0.8///单位是M
        
        manager.activityType = .other
    }
    
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse
        || authorizationStatus == .authorizedAlways
    }
    
    var isPreciseLocationEnabled: Bool {
        accuracyAuthorization == .fullAccuracy
    }
    
    func requestAuthorizationAndStart() {
        #if DEBUG
        if PreviewAPI.isEnabled { return }
        #endif
        if isAuthorized {
            guard CLLocationManager.locationServicesEnabled() else {
                locationError = "系统定位服务未开启"
                return
            }
            
        }
        
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .restricted:
            locationError = "当前设备限制了定位服务"
        case .denied:
            locationError = "定位权限已关闭，请前往系统设置开启"
        @unknown default:
            locationError = "无法确认当前定位权限"
        }
    }
    
    func startUpdatingLocation() {
        #if DEBUG
        if PreviewAPI.isEnabled { return }
        #endif
        guard isAuthorized else {
            return
        }
        
        locationError = nil
        manager.startUpdatingLocation()
        if wantsHeading, CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func setHeadingUpdatesEnabled(_ enabled: Bool) {
        wantsHeading = enabled
        if enabled, isAuthorized, CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        } else {
            manager.stopUpdatingHeading()
            heading = nil
        }
    }
    
    func requestCurrentLocation() {
        #if DEBUG
        if PreviewAPI.isEnabled { return }
        #endif
        guard isAuthorized else {
            requestAuthorizationAndStart()
            return
        }
        
        locationError = nil
        manager.requestLocation()
    }
    
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        heading = nil
    }
}

extension MapLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in heading = newHeading }
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            accuracyAuthorization = manager.accuracyAuthorization
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                startUpdatingLocation()
            case .denied:
                locationError = "定位权限已关闭，请前往系统设置开启"
            case .restricted:
                locationError = "当前设备限制了定位服务"
            case .notDetermined:
                break
            @unknown default:
                locationError = "无法确认当前定位权限"
            }
        }
    }
    
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let newestLocation = locations.last,
              newestLocation.horizontalAccuracy >= 0 else {
            return
        }
        
        Task { @MainActor in
            location = newestLocation
            accuracyAuthorization = manager.accuracyAuthorization
            locationError = nil
        }
    }
    
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        guard let coreLocationError = error as? CLError,
              coreLocationError.code == .locationUnknown else {
            Task { @MainActor in
                locationError = error.localizedDescription
            }
            return
        }
    }
}

struct MapView: View {
    var isActive = true
    @ObservedObject private var contentBrowser = ContentBrowserStore.shared
    @ObservedObject private var routePreview = RoutePreviewStore.shared
    private var hasContentPanel: Bool { contentBrowser.isPresented || routePreview.isPresented }
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var campusMap = CampusMapStore.shared
    @ObservedObject private var navigation = StudentNavigationStore.shared
    @State private var searchBarHeight: CGFloat = 0
    @StateObject private var locationManager = MapLocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasCenteredOnUser = false
    @State private var navigationCameraMode: NavigationCameraMode = .northUp
    @State private var isFollowingNavigation = false
    @State private var stableNavigationHeading: CLLocationDirection?
    @State private var lastCameraLocation: CLLocation?
    @State private var lastCameraHeading: CLLocationDirection?
    @State private var didInitializeNavigationCamera = false
    @State private var followedNavigationSessionID: String?
    
    @State var isToolDrawExpand = false

    private var navigationCameraAvailable: Bool {
        guard navigation.isGuiding, navigation.isCurrent, let plan = navigation.plan, plan.hasRoute,
              plan.mapHash == campusMap.snapshot?.hash,
              let frame = campusMap.snapshot?.document.frames.first(where: { $0.id == campusMap.selectedFrameID }),
              frame.bindings["mapkit"] != nil,
              plan.route?.frameId == frame.id else { return false }
        return true
    }
    
    
    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottom) {
                CampusMapSurface(cameraPosition: $cameraPosition,
                                 location: locationManager.location,
                                 controlsTopInset: searchBarHeight,
                                 controlsHidden: isToolDrawExpand,
                                 navigationCameraMode: navigationCameraMode,
                                 navigationCameraAvailable: navigationCameraAvailable,
                                 toggleNavigationCamera: toggleNavigationCamera)
                VStack {
                    VStack(alignment: .leading, spacing: 0) {
                        CampusMapStatusRow()
                        StatusBar(
                            schoolID: 1,
                            compoundID: 1,
                            departmentID: 1,
                            classID: 301,
                            currentLocation: locationManager.location,
                            recentlyViewed: contentBrowser.recent,
                            onOpenRecentlyViewed: { contentBrowser.open($0.contentReference) }
                        )
                    }

                    HStack(alignment: .center) {
                        ToolDrawerButton(isExpand: $isToolDrawExpand)
                            .anchorPreference(key: ToolDrawerAnchorKey.self, value: .bounds) { $0 }
                            .opacity(isToolDrawExpand ? 0 : 1)
                            .allowsHitTesting(!isToolDrawExpand)
                        locationStatusCard
                    }
                }
                
                .padding()
                
                .padding(.bottom, screen.height/60 + 22)
                .opacity(hasContentPanel ? 0 : 1)
                .allowsHitTesting(!hasContentPanel)
            }
            .accessibilityHidden(isToolDrawExpand)
            if hasContentPanel {
                VStack {
                    Spacer(minLength: 0)
                    CampusMapStatusRow().padding(.horizontal)
                    Color.clear.frame(height: contentBrowser.panelHeight)
                }.allowsHitTesting(true)
            }
            SearchBar()
                .readSize { searchBarHeight = $0.height }
                .accessibilityHidden(isToolDrawExpand)
        }
        // Resolve the trigger's bounds here so the drawer floats above all map
        // controls while the bottom row keeps its original size and position.
        .overlayPreferenceValue(ToolDrawerAnchorKey.self) { anchor in
            GeometryReader { geometry in
                if isToolDrawExpand, let anchor {
                    ToolDrawer(
                        isExpand: $isToolDrawExpand,
                        sourceBounds: geometry[anchor],
                        containerSize: geometry.size,
                        topInset: geometry.safeAreaInsets.top,
                        recentlyViewed: contentBrowser.recent,
                        onOpenProduct: { contentBrowser.open(.product($0.productID)) },
                        onOpenSale: { contentBrowser.open(.promotion($0.saleID)) }
                    )
                    .transition(.opacity)
                }
            }
            .allowsHitTesting(isToolDrawExpand)
        }
        
        .task(id: "\(authSession.currentUser?.userID ?? -1)-\(isActive)") {
            guard isActive, let userID = authSession.currentUser?.userID else { return }
            await campusMap.load(userID: userID)
        }
        .onChange(of: authSession.currentUser?.userID) { _, userID in
            loadNavigationCameraPreference(userID: userID)
            isFollowingNavigation = false
            stableNavigationHeading = nil
            lastCameraLocation = nil
            lastCameraHeading = nil
            followedNavigationSessionID = nil
        }
        .onChange(of: scenePhase) { _, phase in
            guard isActive else { return }
            navigation.setPaused(phase != .active)
            configureHeadingUpdates()
            if phase == .active { updateNavigationCamera(animated: false) }
            if phase == .active, let userID = authSession.currentUser?.userID {
                Task {
                    await campusMap.load(userID: userID, force: true)
                    if navigation.isGuiding, navigation.plan != nil { await navigation.replan() }
                }
            }
        }
        .onChange(of: isActive) { _, active in
            navigation.setPaused(!active)
            if active {
                locationManager.requestAuthorizationAndStart()
                configureHeadingUpdates()
            } else {
                locationManager.setHeadingUpdatesEnabled(false)
                locationManager.stopUpdatingLocation()
            }
        }
        .onAppear {
            guard isActive else { return }
            loadNavigationCameraPreference(userID: authSession.currentUser?.userID)
            if !didInitializeNavigationCamera {
                isFollowingNavigation = navigationCameraAvailable
                followedNavigationSessionID = navigationCameraAvailable ? navigation.plan?.sessionID : nil
                didInitializeNavigationCamera = true
            }
            configureHeadingUpdates()
            Task {
                ///主动申请定位权限并开始持续更新位置
                navigation.setPaused(false)
                locationManager.requestAuthorizationAndStart()
                if let location = locationManager.location {
                    if navigationCameraAvailable {
                        updateNavigationCamera(animated: true)
                    } else {
                        centerMap(on: location, animated: true)
                    }
                } else {
                    locationManager.requestCurrentLocation()
                }
            }
        }
        
        .onDisappear {
            locationManager.setHeadingUpdatesEnabled(false)
            locationManager.stopUpdatingLocation()
            navigation.setPaused(true)
        }
        .onChange(of: navigationCameraAvailable) { _, available in
            if available, followedNavigationSessionID != navigation.plan?.sessionID {
                isFollowingNavigation = true
                followedNavigationSessionID = navigation.plan?.sessionID
            }
            stableNavigationHeading = nil
            lastCameraLocation = nil
            lastCameraHeading = nil
            configureHeadingUpdates()
            if available { updateNavigationCamera(animated: true) }
        }
        .onChange(of: navigationCameraMode) { _, _ in
            if let userID = authSession.currentUser?.userID {
                UserDefaults.standard.set(navigationCameraMode.rawValue, forKey: cameraPreferenceKey(for: userID))
            }
            stableNavigationHeading = nil
            lastCameraLocation = nil
            lastCameraHeading = nil
            configureHeadingUpdates()
            if navigationCameraAvailable { updateNavigationCamera(animated: true) }
        }
        .onChange(of: cameraPosition) { _, position in
            if navigationCameraAvailable, isFollowingNavigation, position.positionedByUser {
                isFollowingNavigation = false
            }
        }
        .onReceive(locationManager.$heading) { _ in
            if navigationCameraMode == .forward { updateNavigationCamera(animated: false) }
        }
        
        .onChange(of: locationManager.location) { _, newLocation in
            guard isActive, let newLocation else { return }
            routePreview.updateLocation(newLocation)

            if navigationCameraAvailable {
                updateNavigationCamera(animated: false)
                return
            }

            if !hasCenteredOnUser, campusMap.snapshot == nil {
                ///首次定位后自动移动到当前位置
                centerMap(on: newLocation, animated: true)
                hasCenteredOnUser = true
            }
        }
    }
    
    
    
    @ViewBuilder var locationStatusCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let location = locationManager.location {
                    Text("当前位置")
                        .font(.headline)
                    
                    Text(accuracyDescription(for: location))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !locationManager.isPreciseLocationEnabled {
                        Text("当前使用的是大致位置")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                } else if let locationError = locationManager.locationError {
                    Text("无法获取当前位置")
                        .font(.headline)
                    
                    Text(locationError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("正在确定当前位置…")
                        .font(.headline)
                    
                    Text("首次定位可能需要几秒钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 8)
            
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .foregroundStyle(.blue)
                .background {
                    Circle()
                        .fill(Material.thick)
                }
                .beButton(recenterMap)
                .buttonStyle(.plain)
                .accessibilityLabel("回到当前位置")
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func centerMap(
        on location: CLLocation,
        animated: Bool
    ) {
        let fallbackCamera = MapCamera(
            centerCoordinate: location.coordinate,
            distance: 350,
            heading: 0,
            pitch: 0
        )
        
        let newPosition = MapCameraPosition.userLocation(
            followsHeading: false,
            fallback: .camera(fallbackCamera)
        )
        
        if animated {
            withAnimation(.easeInOut(duration: 0.45)) {
                cameraPosition = newPosition
            }
        } else {
            cameraPosition = newPosition
        }
    }

    private func recenterMap() {
        guard let location = locationManager.location else {
            locationManager.requestCurrentLocation()
            return
        }
        if navigationCameraAvailable {
            isFollowingNavigation = true
            lastCameraLocation = nil
            updateNavigationCamera(animated: true)
        } else {
            centerMap(on: location, animated: true)
        }
    }

    private func toggleNavigationCamera() {
        navigationCameraMode = navigationCameraMode == .northUp ? .forward : .northUp
    }

    private func cameraPreferenceKey(for userID: Int) -> String {
        "campura.navigation.camera-mode.\(userID)"
    }

    private func loadNavigationCameraPreference(userID: Int?) {
        navigationCameraMode = userID.flatMap {
            UserDefaults.standard.string(forKey: cameraPreferenceKey(for: $0))
        }.flatMap(NavigationCameraMode.init(rawValue:)) ?? .northUp
    }

    private func configureHeadingUpdates() {
        locationManager.setHeadingUpdatesEnabled(
            isActive && scenePhase == .active && navigationCameraAvailable && navigationCameraMode == .forward
        )
    }

    private func updateNavigationCamera(animated: Bool) {
        guard navigationCameraAvailable, isFollowingNavigation,
              let location = locationManager.location,
              let frame = campusMap.snapshot?.document.frames.first(where: { $0.id == campusMap.selectedFrameID }),
              CampusMapGeometry.gpsOrigin(location, frame: frame) != nil else { return }

        var cameraHeading: CLLocationDirection = 0
        var pitch: Double = 0
        if navigationCameraMode == .forward {
            if let heading = reliableHeading(for: location) {
                if let previous = stableNavigationHeading {
                    let change = (heading - previous + 540).truncatingRemainder(dividingBy: 360) - 180
                    stableNavigationHeading = (previous + change * 0.35 + 360).truncatingRemainder(dividingBy: 360)
                } else {
                    stableNavigationHeading = heading
                }
            }
            if let stableNavigationHeading {
                cameraHeading = stableNavigationHeading
                pitch = 38
            }
        }

        let moved = lastCameraLocation.map { location.distance(from: $0) >= 1 } ?? true
        let turned = lastCameraHeading.map {
            abs((cameraHeading - $0 + 540).truncatingRemainder(dividingBy: 360) - 180) >= 2
        } ?? true
        guard animated || moved || turned else { return }

        let distance = cameraPosition.camera?.distance ?? 250
        let center: CLLocationCoordinate2D
        if pitch > 0 {
            let lookAhead = min(35, max(15, distance * 0.1))
            let origin = MKMapPoint(location.coordinate)
            let points = lookAhead * MKMapPointsPerMeterAtLatitude(location.coordinate.latitude)
            let radians = cameraHeading * .pi / 180
            center = MKMapPoint(x: origin.x + sin(radians) * points,
                                y: origin.y - cos(radians) * points).coordinate
        } else {
            center = location.coordinate
        }
        let next = MapCameraPosition.camera(MapCamera(
            centerCoordinate: center, distance: distance, heading: cameraHeading, pitch: pitch
        ))
        lastCameraLocation = location
        lastCameraHeading = cameraHeading
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) { cameraPosition = next }
        } else {
            cameraPosition = next
        }
    }

    private func reliableHeading(for location: CLLocation) -> CLLocationDirection? {
        if let heading = locationManager.heading,
           abs(heading.timestamp.timeIntervalSinceNow) <= 5,
           (0...30).contains(heading.headingAccuracy), heading.trueHeading >= 0 {
            return heading.trueHeading
        }
        if location.speed >= 1.2, location.course >= 0,
           (0...30).contains(location.courseAccuracy) {
            return location.course
        }
        return nil
    }
    
    private func accuracyDescription(for location: CLLocation) -> String {
        let accuracy = max(location.horizontalAccuracy, 0)
        
        if accuracy < 10 {
            return "定位精度约 ±\(Int(accuracy.rounded())) 米"
        }
        
        return "定位精度约 ±\(Int(accuracy.rounded())) 米"
    }
}


