import SwiftUI
import MapKit
import CamapKit

/// All three modes use the same MapKit camera/projection. An opaque canvas hides
/// only the basemap in drawing mode, so changing modes never resets gestures/zoom.
struct CampusMapDrawing: View {
    let document: CamapDocument?
    let frameID: String?
    let mode: CampusMapDisplayMode
    let selectedFeatureID: String?
    let plan: NavigationPlan?
    let suggestion: NavigationSuggestion?
    let location: CLLocation?
    let projectionRevision: Int
    let screenPoint: (Point, String) -> CGPoint?
    let locationPoint: (CLLocationCoordinate2D) -> CGPoint?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let nodes = Dictionary(uniqueKeysWithValues: (document?.nodes ?? []).map { ($0.id, $0) })
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -40, dy: -40)
            if mode == .drawing {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(uiColor: .systemBackground)))
            }
            if mode != .original, let document, let frameID {
                for edge in document.edges where edge.frameId == frameID {
                    let points = edge.points.isEmpty
                        ? [nodes[edge.from]?.position, nodes[edge.to]?.position].compactMap { $0 }
                        : edge.points
                    if let path = path(points, frameID: frameID, bounds: bounds) {
                        context.stroke(path, with: .color(edge.closed ? .red.opacity(0.6) : .secondary.opacity(0.35)),
                                       style: StrokeStyle(lineWidth: edge.covered ? 5 : 3, lineCap: .round))
                    }
                }
                var labelCount = 0
                for feature in document.features where feature.frameId == frameID && feature.levelId == nil {
                    guard let path = path(feature.geometry.points, frameID: frameID, bounds: bounds,
                                          closed: isPolygon(feature.geometry)) else { continue }
                    let selected = feature.id == selectedFeatureID
                    let tint: Color = feature.kind == "building" ? .accentColor : .secondary
                    switch feature.geometry {
                    case .polygon:
                        context.fill(path, with: .color(tint.opacity(selected ? 0.3 : colorScheme == .dark ? 0.18 : 0.1)))
                        context.stroke(path, with: .color(tint.opacity(selected ? 0.95 : 0.55)), lineWidth: selected ? 2.5 : 1)
                    case .line:
                        context.stroke(path, with: .color(tint.opacity(0.7)), lineWidth: selected ? 3 : 1.5)
                    case .point(let point):
                        if let p = screenPoint(point, frameID) {
                            let rect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                            context.fill(Path(ellipseIn: rect), with: .color(selected ? .accentColor : .secondary))
                        }
                    }
                    if !feature.name.isEmpty, labelCount < 100,
                       let point = screenPoint(CampusMapGeometry.center(of: feature.geometry.points), frameID), bounds.contains(point) {
                        labelCount += 1
                        context.draw(Text(feature.name).font(.caption2.weight(selected ? .bold : .medium))
                            .foregroundStyle(Color.primary), at: CGPoint(x: point.x, y: point.y + 13))
                    }
                }
            }
            // Route presentation is data-driven; no route panel is introduced here.
            for overlay in plan?.overlays ?? [] where overlay.frameId == frameID {
                let red = overlay.kind == "closure"
                let tint: Color = red ? .red : .orange
                if case .point(let local) = overlay.geometry,
                   let point = screenPoint(local, overlay.frameId), bounds.contains(point) {
                    let rect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.3)))
                    context.stroke(Path(ellipseIn: rect), with: .color(tint), lineWidth: 2)
                }
                if let path = path(overlay.geometry.points, frameID: overlay.frameId, bounds: bounds,
                                   closed: isPolygon(overlay.geometry)) {
                    if isPolygon(overlay.geometry) { context.fill(path, with: .color(tint.opacity(0.18))) }
                    context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 2.5, dash: red ? [] : [5, 4]))
                }
            }
            drawRoute(plan?.route, dashed: false, context: &context, bounds: bounds)
            drawRoute(suggestion?.route, dashed: true, context: &context, bounds: bounds)
            if mode == .drawing, let location, let document,
               document.frames.first(where: { $0.id == frameID })?.bindings["mapkit"] != nil,
               let point = locationPoint(location.coordinate), bounds.contains(point) {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)), with: .color(.blue))
            }
        }
        .background {
            if mode == .drawing { Color(uiColor: .systemBackground).ignoresSafeArea() }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func path(_ points: [Point], frameID: String, bounds: CGRect, closed: Bool = false) -> Path? {
        let projected = points.compactMap { screenPoint($0, frameID) }
        guard projected.count == points.count, let first = projected.first,
              projected.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let minX = projected.map(\.x).min()!, maxX = projected.map(\.x).max()!
        let minY = projected.map(\.y).min()!, maxY = projected.map(\.y).max()!
        guard bounds.intersects(CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))) else { return nil }
        return Path { path in
            path.move(to: first)
            for point in projected.dropFirst() { path.addLine(to: point) }
            if closed { path.closeSubpath() }
        }
    }

    private func isPolygon(_ geometry: Geometry) -> Bool {
        if case .polygon = geometry { return true }; return false
    }

    private func drawRoute(_ route: NavigationRoute?, dashed: Bool, context: inout GraphicsContext, bounds: CGRect) {
        guard let route, route.frameId == frameID,
              let path = path(route.polyline, frameID: route.frameId, bounds: bounds) else { return }
        if !dashed { context.stroke(path, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)) }
        context.stroke(path, with: .color(.blue.opacity(dashed ? 0.65 : 1)),
                       style: StrokeStyle(lineWidth: dashed ? 4 : 5, lineCap: .round, lineJoin: .round, dash: dashed ? [7, 6] : []))
    }
}
