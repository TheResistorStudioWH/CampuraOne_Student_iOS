import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Run with: swift render.swift
// The location marker stays separate from the provisional outer arc.
private let side = 1024
private let center = CGPoint(x: 512, y: 512)
private let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

private func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [
        CGFloat((hex >> 16) & 255) / 255,
        CGFloat((hex >> 8) & 255) / 255,
        CGFloat(hex & 255) / 255,
        alpha
    ])!
}

private func canvas() -> CGContext {
    let context = CGContext(
        data: nil, width: side, height: side,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.translateBy(x: 0, y: CGFloat(side))
    context.scaleBy(x: 1, y: -1)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    return context
}

private func background(_ context: CGContext) {
    context.setFillColor(color(0x151B2C))
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
}

private func heading(_ context: CGContext) {
    context.saveGState()
    let radius: CGFloat = 328
    let halfAngle: CGFloat = .pi / 5.5
    context.beginPath()
    context.move(to: center)
    context.addLine(to: CGPoint(
        x: center.x + radius * cos(-halfAngle),
        y: center.y + radius * sin(-halfAngle)
    ))
    context.addArc(center: center, radius: radius,
                   startAngle: -halfAngle, endAngle: halfAngle, clockwise: false)
    context.closePath()
    context.clip()

    let gradient = CGGradient(colorsSpace: colorSpace, colors: [
        color(0x1684FA, 0.56),
        color(0x1684FA, 0.40),
        color(0x1684FA, 0.25),
        color(0x1684FA, 0.02)
    ] as CFArray, locations: [0, 0.26, 0.72, 1])!
    context.drawRadialGradient(
        gradient, startCenter: center, startRadius: 0,
        endCenter: center, endRadius: radius,
        options: []
    )
    context.restoreGState()
}

private func ring(_ context: CGContext) {
    // Placeholder: a 270-degree C with a right-facing gap.
    let radius: CGFloat = 302
    let endAngle: CGFloat = .pi / 4
    let start = CGPoint(x: center.x + radius * cos(endAngle),
                        y: center.y + radius * sin(endAngle))
    context.setStrokeColor(color(0xF8D99A))
    context.setLineWidth(116)
    context.setLineCap(.round)
    context.beginPath()
    context.move(to: start)
    context.addArc(center: center, radius: radius,
                   startAngle: endAngle, endAngle: 2 * .pi - endAngle,
                   clockwise: false)
    context.strokePath()
}

private func leaves(_ context: CGContext) {
    // A strawberry-like calyx: six broad pointed sepals share one short crown.
    // Their tips follow the C's upper-left curve, with no stem or outline.
    let crown = CGPoint(x: 275, y: 252)
    let clockwiseRotation: CGFloat = 30
    let sepals: [(angle: CGFloat, length: CGFloat, width: CGFloat)] = [
        (-68, 139, 30),
        (-35, 179, 33),
        (-4, 236, 36),
        (26, 225, 38),
        (56, 200, 36),
        (86, 184, 32)
    ]
    context.saveGState()
    context.setFillColor(color(0xBFFB8B))
    for sepal in sepals {
        let angle = (sepal.angle + clockwiseRotation) * .pi / 180
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(x: crown.x + direction.x * along + normal.x * across,
                    y: crown.y + direction.y * along + normal.y * across)
        }
        let path = CGMutablePath()
        path.move(to: point(0, 0))
        path.addCurve(to: point(sepal.length, 0),
                      control1: point(sepal.length * 0.27, sepal.width * 0.92),
                      control2: point(sepal.length * 0.69, sepal.width * 1.18))
        path.addCurve(to: point(0, 0),
                      control1: point(sepal.length * 0.69, -sepal.width * 1.18),
                      control2: point(sepal.length * 0.27, -sepal.width * 0.92))
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
    }
    context.restoreGState()
}

private func location(_ context: CGContext) {
    let outer = CGRect(x: center.x - 86, y: center.y - 86, width: 172, height: 172)
    let inner = CGRect(x: center.x - 64, y: center.y - 64, width: 128, height: 128)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 9), blur: 22,
                      color: color(0x081126, 0.32))
    context.setFillColor(color(0xD5DAE2))
    context.fillEllipse(in: outer)
    context.restoreGState()
    context.setFillColor(color(0xD5DAE2))
    context.fillEllipse(in: outer)
    context.setFillColor(color(0x1684FA))
    context.fillEllipse(in: inner)
}

private func png(_ image: CGImage, named name: String) {
    let destination = CGImageDestinationCreateWithURL(
        output.appendingPathComponent(name) as CFURL,
        UTType.png.identifier as CFString, 1, nil
    )!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "Could not save \(name)")
}

private func render(_ name: String, _ draw: (CGContext) -> Void) {
    let context = canvas()
    draw(context)
    png(context.makeImage()!, named: name)
}

render("01-background.png", background)
render("02-heading.png", heading)
render("03-outer-arc.png", ring)
render("03b-leaves.png", leaves)
render("04-location.png", location)

let preview = canvas()
background(preview)
heading(preview)
ring(preview)
leaves(preview)
location(preview)
png(preview.makeImage()!, named: "preview.png")

let watchPreview = canvas()
watchPreview.addEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
watchPreview.clip()
background(watchPreview)
heading(watchPreview)
ring(watchPreview)
leaves(watchPreview)
location(watchPreview)
png(watchPreview.makeImage()!, named: "preview-watch.png")

let packageAssets = output.appendingPathComponent("AppIcon.icon/Assets", isDirectory: true)
try FileManager.default.createDirectory(
    at: packageAssets, withIntermediateDirectories: true
)
for name in ["02-heading.png", "03-outer-arc.png", "03b-leaves.png", "04-location.png"] {
    let source = output.appendingPathComponent(name)
    let destination = packageAssets.appendingPathComponent(name)
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: source, to: destination)
}
