import Foundation
import MapKit
import CamapKit

enum CampusMapDisplayMode: String, CaseIterable, Identifiable {
    case blended, drawing, original
    var id: Self { self }
    var title: String {
        switch self {
        case .blended: return "融合"
        case .drawing: return "仅绘制图"
        case .original: return "仅原地图"
        }
    }
    var symbol: String {
        switch self {
        case .blended: return "square.3.layers.3d"
        case .drawing: return "map"
        case .original: return "globe.asia.australia"
        }
    }
}

/// Navigation camera preference is independent of the campus basemap mode.
enum NavigationCameraMode: String {
    case northUp, forward

    var title: String {
        switch self {
        case .northUp: return "正北朝上"
        case .forward: return "前进方向"
        }
    }

    var symbol: String {
        switch self {
        case .northUp: return "location.north.line.fill"
        case .forward: return "location.north.fill"
        }
    }
}

/// A visual placement is never a real calibration and never becomes a GPS origin.
nonisolated struct TemporaryCampusPlacement: Equatable, Sendable {
    var longitude: Double
    var latitude: Double
    var rotation: Double = 0
    let localAnchor: Point

    func project(_ point: Point) -> CLLocationCoordinate2D {
        let binding = CamapKit.Binding(longitude: longitude, latitude: latitude, rotation: rotation)
        let projected = binding.project(Point(point.x - localAnchor.x, point.y - localAnchor.y))
        return CLLocationCoordinate2D(latitude: projected.y, longitude: projected.x)
    }
}

nonisolated enum CampusMapGeometry {
    /// Seed an uncalibrated drawing near its campus, rather than the arbitrary
    /// initial MapKit viewport. The SDK conversion is approximate: this remains
    /// a session-only visual placement, never a real MapKit binding or GPS origin.
    static func initialPlacement(frame: SpatialFrame, points: [Point],
                                 fallbackCenter: CLLocationCoordinate2D) -> TemporaryCampusPlacement {
        // Calibration exports already contain Apple-observed coordinates. Never
        // apply the AMap conversion again, even when resetting the viewport.
        if let binding = frame.bindings["mapkit"] {
            return TemporaryCampusPlacement(longitude: binding.longitude, latitude: binding.latitude,
                                            rotation: binding.rotation, localAnchor: Point(0, 0))
        }
        if let binding = frame.bindings["amap"],
           let origin = try? CoordinateConversion.gcj02ToWGS84(Point(binding.longitude, binding.latitude)) {
            return TemporaryCampusPlacement(longitude: origin.x, latitude: origin.y,
                                            rotation: binding.rotation, localAnchor: Point(0, 0))
        }
        return TemporaryCampusPlacement(longitude: fallbackCenter.longitude, latitude: fallbackCenter.latitude,
                                        localAnchor: center(of: points))
    }

    static func points(in document: CamapDocument, frameID: String) -> [Point] {
        document.features.filter { $0.frameId == frameID }.flatMap(\.geometry.points)
        + document.nodes.filter { $0.frameId == frameID }.map(\.position)
        + document.edges.filter { $0.frameId == frameID }.flatMap(\.points)
    }

    static func center(of points: [Point]) -> Point {
        guard let first = points.first else { return Point(0, 0) }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return Point((minX + maxX) / 2, (minY + maxY) / 2)
    }

    static func coordinate(_ point: Point, frame: SpatialFrame,
                           temporary: TemporaryCampusPlacement?) -> CLLocationCoordinate2D? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        let coordinate: CLLocationCoordinate2D?
        if let binding = frame.bindings["mapkit"] {
            let p = binding.project(point)
            coordinate = CLLocationCoordinate2D(latitude: p.y, longitude: p.x)
        } else {
            coordinate = temporary?.project(point)
        }
        guard let coordinate, CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        return coordinate
    }

    static func gpsOrigin(_ location: CLLocation, frame: SpatialFrame, now: Date = Date()) -> NavigationOrigin? {
        guard frame.bindings["mapkit"] != nil, location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 30, abs(location.timestamp.timeIntervalSince(now)) <= 60 else { return nil }
        return .mapkit(frameID: frame.id, longitude: location.coordinate.longitude,
                       latitude: location.coordinate.latitude, accuracyMeters: location.horizontalAccuracy)
    }
}

/// Fitting uses the actual unobstructed map area, not screen-sized offsets.
nonisolated enum CampusMapViewport {
    static func fittingRect(coordinates: [CLLocationCoordinate2D], size: CGSize,
                            topInset: CGFloat, bottomInset: CGFloat, minimumMeters: Double = 80) -> MKMapRect? {
        let coordinates = coordinates.filter { CLLocationCoordinate2DIsValid($0) && $0.latitude.isFinite && $0.longitude.isFinite }
        let points = coordinates.map(MKMapPoint.init)
        guard let first = points.first, size.width > 0, size.height > 0 else { return nil }
        let top = max(0, topInset), bottom = max(0, bottomInset)
        let visibleHeight = size.height - top - bottom
        // A nearly full-height details sheet is for reading, not a tiny-map refit.
        guard visibleHeight >= max(64, size.height * 0.18) else { return nil }
        let usableWidth = max(1, size.width - 48)
        let minX = points.map(\.x).min()!, maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!, maxY = points.map(\.y).max()!
        let metersPerPoint = MKMetersPerMapPointAtLatitude(first.coordinate.latitude)
        guard metersPerPoint.isFinite, metersPerPoint > 0 else { return nil }
        let scale = max((maxX - minX) * 1.3 / usableWidth,
                        (maxY - minY) * 1.3 / max(1, visibleHeight - 40),
                        minimumMeters / metersPerPoint / visibleHeight)
        let width = scale * size.width, height = scale * size.height
        let centerY = (minY + maxY) / 2 + scale * (bottom - top) / 2
        return MKMapRect(x: (minX + maxX) / 2 - width / 2, y: centerY - height / 2, width: width, height: height)
    }
}

/// Small deterministic screen-space clusters keep separate buildings reachable
/// without stacking a wall of labels. These points are never used as GPS.
nonisolated enum CampusMarkerLayout {
    struct Item {
        let id: String
        let point: CGPoint
    }
    struct Cluster: Identifiable {
        var items: [Item]
        var id: String { items.map(\.id).sorted().joined(separator: "|") }
        var center: CGPoint {
            CGPoint(x: items.map(\.point.x).reduce(0, +) / CGFloat(items.count),
                    y: items.map(\.point.y).reduce(0, +) / CGFloat(items.count))
        }
    }

    static func clusters(_ items: [Item], separation: CGFloat = 64) -> [Cluster] {
        var clusters: [Cluster] = []
        for item in items.filter({ $0.point.x.isFinite && $0.point.y.isFinite }).sorted(by: { $0.id < $1.id }) {
            if let index = clusters.firstIndex(where: { cluster in
                hypot(cluster.center.x - item.point.x, cluster.center.y - item.point.y) < separation
                    && cluster.items.allSatisfy { hypot($0.point.x - item.point.x, $0.point.y - item.point.y) < separation * 1.6 }
            }) {
                clusters[index].items.append(item)
            } else { clusters.append(Cluster(items: [item])) }
        }
        return clusters
    }
}
