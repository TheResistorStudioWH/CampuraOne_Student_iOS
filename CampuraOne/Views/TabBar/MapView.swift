//
//  MapView.swift
//  CampuraOne
//
//  Created by LShayc1own on 20/05/2026.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import Combine

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
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
        guard isAuthorized else {
            return
        }
        
        locationError = nil
        manager.startUpdatingLocation()
    }
    
    func requestCurrentLocation() {
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
    @StateObject private var locationManager = MapLocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasCenteredOnUser = false
    
    @State var isToolDrawExpand = false
    
    
    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                }
                .ignoresSafeArea(.keyboard)
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapPitchToggle()
                }
                VStack {
                    StatusBar(schoolID: 1, compoundID: 1, departmentID: 1, classID: 301)
                    
                    HStack(alignment: isToolDrawExpand ? .bottom : .center) {
                        ToolDrawer(isExpand: $isToolDrawExpand)
                        locationStatusCard
                    }
                }
                
                .padding()
                
                .padding(.bottom, screen.height/60 + 22)
            }
            SearchBar()
        }
        
        .onAppear {
            Task {
                ///主动申请定位权限并开始持续更新位置
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
        }
        
        .onChange(of: locationManager.location) { _, newLocation in
            guard let newLocation else {
                return
            }
            
            if !hasCenteredOnUser {
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



