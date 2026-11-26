import SwiftUI

/// Visual language: a field instrument. Matte black housing, an off-white
/// engraved scale, a single safety-orange hairline, monospaced figures.
enum Theme {
    // Housing & panels
    static let housing   = Color(red: 0.070, green: 0.074, blue: 0.080)
    static let panel     = Color(red: 0.110, green: 0.115, blue: 0.125)
    static let bezel     = Color(white: 0.30)
    static let bezelDark = Color(white: 0.16)

    // Scale (the "drum" you read through the window)
    static let scale     = Color(red: 0.95, green: 0.93, blue: 0.88)
    static let ink       = Color(red: 0.08, green: 0.08, blue: 0.08)

    // Signals
    static let accent    = Color(red: 1.00, green: 0.36, blue: 0.12)  // safety orange
    static let ok        = Color(red: 0.36, green: 0.86, blue: 0.46)
    static let warn      = Color(red: 1.00, green: 0.76, blue: 0.22)

    // Text on housing
    static let readout   = Color(red: 0.95, green: 0.93, blue: 0.88)
    static let label     = Color(white: 0.58)

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Small engraved-style caption: uppercase, wide tracking.
    static let caption = Font.system(size: 10, weight: .semibold, design: .monospaced)
}

extension View {
    /// Engraved caption styling used for all instrument labels.
    func engravedLabel(_ color: Color = Theme.label) -> some View {
        self.font(Theme.caption)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

enum Format {
    /// "+08.4" style: always signed, fixed width, so digits don't jump around.
    static func signed(_ value: Double, decimals: Int = 1, width: Int = 5) -> String {
        let v = abs(value) < 0.05 ? 0 : value   // avoid "-0.0"
        return String(format: "%+0\(width).\(decimals)f", v)
    }
}
