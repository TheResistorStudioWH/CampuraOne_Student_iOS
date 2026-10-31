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
        if let binding = frame.bindings["mapkit"] {
            let p = binding.project(point)
            return CLLocationCoordinate2D(latitude: p.y, longitude: p.x)
        }
        return temporary?.project(point)
    }

    static func gpsOrigin(_ location: CLLocation, frame: SpatialFrame, now: Date = Date()) -> NavigationOrigin? {
        guard frame.bindings["mapkit"] != nil, location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 30, abs(location.timestamp.timeIntervalSince(now)) <= 60 else { return nil }
        return .mapkit(frameID: frame.id, longitude: location.coordinate.longitude,
                       latitude: location.coordinate.latitude, accuracyMeters: location.horizontalAccuracy)
    }
}
