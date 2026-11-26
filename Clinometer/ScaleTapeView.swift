import SwiftUI

/// A rolling scale drum like the one you read through an optical clinometer's
/// window: degrees on the left, percent grade on the right, both on the same
/// angular axis so the hairline reads both at once.
struct ScaleTapeView: View {
    /// Angle (degrees) under the hairline.
    var elevation: Double
    var pointsPerDegree: CGFloat = 9

    var body: some View {
        Canvas { ctx, size in
            let midX = size.width / 2
            let midY = size.height / 2
            let halfSpan = Double(midY / pointsPerDegree) + 1

            func y(_ degrees: Double) -> CGFloat {
                midY - CGFloat(degrees - elevation) * pointsPerDegree
            }
            func visible(_ degrees: Double) -> Bool {
                abs(degrees - elevation) <= halfSpan
            }
            func tick(from x0: CGFloat, to x1: CGFloat, at yy: CGFloat, width: CGFloat) {
                var path = Path()
                path.move(to: CGPoint(x: x0, y: yy))
                path.addLine(to: CGPoint(x: x1, y: yy))
                ctx.stroke(path, with: .color(Theme.ink), lineWidth: width)
            }
            func label(_ s: String, x: CGFloat, y yy: CGFloat, anchor: UnitPoint) {
                let text = Text(s)
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundStyle(Theme.ink)
                ctx.draw(text, at: CGPoint(x: x, y: yy), anchor: anchor)
            }

            // Center divider between the two scales.
            var divider = Path()
            divider.move(to: CGPoint(x: midX, y: 0))
            divider.addLine(to: CGPoint(x: midX, y: size.height))
            ctx.stroke(divider, with: .color(Theme.ink.opacity(0.6)), lineWidth: 0.75)

            // Degrees — left half, ticks grow leftward from the divider.
            let lo = Int(max(-90, (elevation - halfSpan).rounded(.down)))
            let hi = Int(min(90, (elevation + halfSpan).rounded(.up)))
            if lo <= hi {
                for d in lo...hi {
                    let yy = y(Double(d))
                    let major = d % 10 == 0, mid = d % 5 == 0
                    let len: CGFloat = major ? 16 : (mid ? 11 : 6)
                    tick(from: midX - len, to: midX, at: yy, width: major || mid ? 1.3 : 0.8)
                    if major {
                        label(Self.signedLabel(d), x: midX - 20, y: yy, anchor: .trailing)
                    }
                }
            }

            // Percent — right half, non-linear spacing (tick at atan(p/100)).
            for p in Self.percentTicks {
                let deg = GradeMath.degrees(fromPercent: Double(p))
                guard visible(deg) else { continue }
                let yy = y(deg)
                let major = p % 10 == 0, mid = p % 5 == 0
                let len: CGFloat = major ? 16 : (mid ? 11 : 6)
                tick(from: midX, to: midX + len, at: yy, width: major || mid ? 1.3 : 0.8)
                let labelled = abs(p) <= 100 ? major : p % 50 == 0
                if labelled {
                    label(Self.signedLabel(p), x: midX + 20, y: yy, anchor: .leading)
                }
            }
        }
        .background(Theme.scale)
        // Shading top and bottom so it reads as a curved drum.
        .overlay(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0),
                    .init(color: .black.opacity(0.0), location: 0.28),
                    .init(color: .black.opacity(0.0), location: 0.72),
                    .init(color: .black.opacity(0.55), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            HStack {
                Text("DEG")
                Spacer()
                Text("%")
            }
            .font(Theme.caption)
            .tracking(1.4)
            .foregroundStyle(Theme.scale)
            .padding(.horizontal, 8)
            .padding(.top, 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Theme.bezel, lineWidth: 1.5)
        )
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.housing)
        )
        .accessibilityElement()
        .accessibilityLabel("Scale")
        .accessibilityValue(String(format: "%.1f degrees", elevation))
    }

    /// −200…200 %: every 1 % to ±50, every 2 % to ±100, every 5 % beyond.
    static let percentTicks: [Int] = (-200...200).filter { p in
        let a = abs(p)
        if a <= 50 { return true }
        if a <= 100 { return p % 2 == 0 }
        return p % 5 == 0
    }

    static func signedLabel(_ value: Int) -> String {
        value > 0 ? "+\(value)" : (value < 0 ? "−\(-value)" : "0")
    }
}

#Preview {
    ScaleTapeView(elevation: 4.6)
        .frame(width: 110, height: 320)
        .padding()
        .background(Color.gray)
}
