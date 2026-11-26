import SwiftUI

/// Sighting reticle drawn over the camera image.
/// - A safety-orange hairline across the full width (it also crosses the scale).
/// - A fine center crosshair with a gap so the target stays visible.
/// - A faint "plumb" line that stays level with the true horizon, so you can
///   see when the phone is rolled sideways.
struct ReticleView: View {
    var roll: Double
    var isHeld: Bool

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let hairline: Color = Theme.accent
            let fine: Color = .white

            // Draw every stroke twice: a dark halo, then the color, so the
            // reticle reads against bright sky and dark forest alike.
            func stroke(_ path: Path, _ color: Color, _ width: CGFloat, dash: [CGFloat] = []) {
                ctx.stroke(path, with: .color(.black.opacity(0.55)),
                           style: StrokeStyle(lineWidth: width + 2, lineCap: .round, dash: dash))
                ctx.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
            }

            let gap: CGFloat = 14

            // Main hairline, broken around the center.
            var h = Path()
            h.move(to: CGPoint(x: 0, y: c.y)); h.addLine(to: CGPoint(x: c.x - gap, y: c.y))
            h.move(to: CGPoint(x: c.x + gap, y: c.y)); h.addLine(to: CGPoint(x: size.width, y: c.y))
            stroke(h, hairline, isHeld ? 2 : 1.2)

            // Vertical crosshair.
            var v = Path()
            v.move(to: CGPoint(x: c.x, y: c.y - 70)); v.addLine(to: CGPoint(x: c.x, y: c.y - gap))
            v.move(to: CGPoint(x: c.x, y: c.y + gap)); v.addLine(to: CGPoint(x: c.x, y: c.y + 70))
            stroke(v, fine, 1)

            // Graduation ticks along the hairline near the center.
            var ticks = Path()
            for i in 1...4 {
                let dx = CGFloat(i) * 20 + gap - 4
                let len: CGFloat = i % 2 == 0 ? 7 : 4
                for x in [c.x - dx, c.x + dx] {
                    ticks.move(to: CGPoint(x: x, y: c.y - len))
                    ticks.addLine(to: CGPoint(x: x, y: c.y + len))
                }
            }
            stroke(ticks, fine, 1)

            // Center dot.
            let dot = Path(ellipseIn: CGRect(x: c.x - 1.5, y: c.y - 1.5, width: 3, height: 3))
            ctx.fill(dot, with: .color(hairline))

            // Plumb line: rotated opposite to the phone's roll, so it stays
            // aligned with the real horizon. Fades out when you're plumb.
            let rollRad = -roll * .pi / 180
            let r: CGFloat = 110
            let dx = CGFloat(cos(rollRad)) * r, dy = CGFloat(sin(rollRad)) * r
            var plumb = Path()
            plumb.move(to: CGPoint(x: c.x - dx, y: c.y - dy))
            plumb.addLine(to: CGPoint(x: c.x + dx, y: c.y + dy))
            let rollAlpha = min(1, max(0, (abs(roll) - 0.5) / 3))
            if rollAlpha > 0 {
                stroke(plumb, Theme.warn.opacity(rollAlpha), 1, dash: [4, 5])
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
