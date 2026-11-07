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
    let isGuiding: Bool
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
                for feature in document.features where feature.frameId == frameID && feature.levelId == nil {
                    guard let path = path(feature.geometry.points, frameID: frameID, bounds: bounds,
                                          closed: isPolygon(feature.geometry)) else { continue }
                    let selected = feature.id == selectedFeatureID
                    let tint: Color = ["building", "merchant"].contains(feature.kind) ? .accentColor : .secondary
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
                }
                drawPlaceLabels(document: document, frameID: frameID, context: &context, bounds: bounds)
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
            if let route = plan?.route, let first = route.polyline.first, let last = route.polyline.last {
                for (index, marker) in [(first, "起点", Color.blue), (last, plan?.destination?.name ?? "终点", Color.orange)].enumerated() {
                    if isGuiding && index == 0 { continue }
                    let (local, title, color) = marker
                    if let point = screenPoint(local, route.frameId), bounds.contains(point) {
                        let circle = Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                        context.fill(circle, with: .color(color))
                        context.stroke(circle, with: .color(.white), lineWidth: 2)
                        drawRouteLabel(title, tint: color, at: CGPoint(x: point.x, y: point.y - 20), context: &context)
                    }
                }
            }
            if let plan, let route = plan.route {
                for (index, stop) in plan.waypoints.enumerated() where index < route.legs.count {
                    if let local = route.legs[index].polyline.last,
                       let point = screenPoint(local, route.frameId), bounds.contains(point) {
                        let circle = Path(ellipseIn: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20))
                        context.fill(circle, with: .color(.green))
                        context.stroke(circle, with: .color(.white), lineWidth: 2)
                        context.draw(Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white), at: point)
                        drawRouteLabel(stop.name, tint: .green, at: CGPoint(x: point.x, y: point.y - 24), context: &context)
                    }
                }
            }
            for overlay in plan?.overlays ?? [] where overlay.frameId == frameID {
                if let point = screenPoint(CampusMapGeometry.center(of: overlay.geometry.points), overlay.frameId), bounds.contains(point) {
                    drawRouteLabel(overlay.kind == "closure" ? "道路封闭" : "通行提醒", tint: overlay.kind == "closure" ? .red : .orange, at: CGPoint(x: point.x, y: point.y - 18), context: &context)
                }
            }
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

    private func drawPlaceLabels(document: CamapDocument, frameID: String, context: inout GraphicsContext, bounds: CGRect) {
        var occupied: [CGRect] = []
        if let route = plan?.route {
            for point in [route.polyline.first, route.polyline.last].compactMap({ $0 }) {
                if let screen = screenPoint(point, route.frameId) {
                    occupied.append(CGRect(x: screen.x - 95, y: screen.y - 40, width: 190, height: 58))
                }
            }
            for leg in route.legs.dropLast() {
                if let point = leg.polyline.last, let screen = screenPoint(point, route.frameId) {
                    occupied.append(CGRect(x: screen.x - 70, y: screen.y - 40, width: 140, height: 60))
                }
            }
        }
        let generic = Set(["建筑", "楼梯", "门", "入口", "出入口"])
        let features = document.features.filter {
            $0.frameId == frameID && $0.levelId == nil && !$0.name.isEmpty && !generic.contains($0.name)
        }.sorted {
            let left = $0.id == selectedFeatureID ? 0 : $0.kind == "building" ? 1 : 2
            let right = $1.id == selectedFeatureID ? 0 : $1.kind == "building" ? 1 : 2
            return left == right ? $0.id < $1.id : left < right
        }
        for feature in features {
            guard let screen = screenPoint(CampusMapGeometry.center(of: feature.geometry.points), frameID), bounds.contains(screen) else { continue }
            let point = CGPoint(x: screen.x, y: screen.y + 13)
            let text = context.resolve(Text(feature.name).font(.caption2.weight(feature.id == selectedFeatureID ? .bold : .medium))
                .foregroundStyle(Color.primary))
            let size = text.measure(in: CGSize(width: 150, height: 30))
            let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
                .insetBy(dx: -7, dy: -5)
            guard !occupied.contains(where: { $0.intersects(rect) }) else { continue }
            occupied.append(rect)
            context.draw(text, at: point)
            if occupied.count > 48 { break }
        }
    }

    private func drawRouteLabel(_ title: String, tint: Color, at point: CGPoint, context: inout GraphicsContext) {
        let text = context.resolve(Text(title).font(.caption.weight(.semibold)).foregroundStyle(tint))
        let size = text.measure(in: CGSize(width: 190, height: 36))
        let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height).insetBy(dx: -6, dy: -3)
        context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(Color(uiColor: .systemBackground).opacity(0.9)))
        context.draw(text, at: point)
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
