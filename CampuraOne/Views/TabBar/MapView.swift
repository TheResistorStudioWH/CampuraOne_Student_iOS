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

#Preview("app - 已登录") {
    PreviewAppView()
}

@MainActor
final class MapLocationManager: NSObject, ObservableObject {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var accuracyAuthorization: CLAccuracyAuthorization
    @Published private(set) var locationError: String?
    
    private let manager = CLLocationManager()
    
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
    }
}

extension MapLocationManager: CLLocationManagerDelegate {
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
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var campusMap = CampusMapStore.shared
    @ObservedObject private var navigation = StudentNavigationStore.shared
    @State private var searchBarHeight: CGFloat = 0
    @StateObject private var locationManager = MapLocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasCenteredOnUser = false
    
    @State var isToolDrawExpand = false
    
    
    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottom) {
                CampusMapSurface(cameraPosition: $cameraPosition,
                                 location: locationManager.location,
                                 controlsTopInset: searchBarHeight,
                                 controlsHidden: isToolDrawExpand)
                VStack {
                    VStack(alignment: .leading, spacing: 0) {
                        CampusMapStatusRow()
                        StatusBar(
                            schoolID: 1,
                            compoundID: 1,
                            departmentID: 1,
                            classID: 301,
                            currentLocation: locationManager.location
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
            }
            .accessibilityHidden(isToolDrawExpand)
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
                        topInset: geometry.safeAreaInsets.top
                    )
                    .transition(.opacity)
                }
            }
            .allowsHitTesting(isToolDrawExpand)
        }
        
        .task(id: authSession.currentUser?.userID) {
            guard let userID = authSession.currentUser?.userID else { return }
            await campusMap.load(userID: userID)
        }
        .onChange(of: scenePhase) { _, phase in
            navigation.setPaused(phase != .active)
            if phase == .active, let userID = authSession.currentUser?.userID {
                Task {
                    await campusMap.load(userID: userID, force: true)
                    if navigation.plan != nil { await navigation.replan() }
                }
            }
        }
        .onAppear {
            Task {
                ///主动申请定位权限并开始持续更新位置
                navigation.setPaused(false)
                locationManager.requestAuthorizationAndStart()
                if let location = locationManager.location {
                    centerMap(on: location, animated: true)
                } else {
                    locationManager.requestCurrentLocation()
                }
            }
        }
        
        .onDisappear {
            locationManager.stopUpdatingLocation()
            navigation.setPaused(true)
        }
        
        .onChange(of: locationManager.location) { _, newLocation in
            guard let newLocation else {
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
                .beButton {
                    if let location = locationManager.location {
                        centerMap(on: location, animated: true)
                    } else {
                        locationManager.requestCurrentLocation()
                    }
                }
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
    
    private func accuracyDescription(for location: CLLocation) -> String {
        let accuracy = max(location.horizontalAccuracy, 0)
        
        if accuracy < 10 {
            return "定位精度约 ±\(Int(accuracy.rounded())) 米"
        }
        
        return "定位精度约 ±\(Int(accuracy.rounded())) 米"
    }
}


