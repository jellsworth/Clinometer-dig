import Foundation

/// Pure math for turning the gravity vector into sighting angles.
///
/// Device coordinate frame (Core Motion, phone in portrait):
///   +x → right edge of the screen
///   +y → top edge of the screen
///   +z → out of the screen, toward the user's face
///
/// The back camera looks along −z. `gravity` is a unit-ish vector pointing
/// toward the ground, expressed in that frame. Upright and level gives
/// roughly (0, −1, 0); lying flat on a table, screen up, gives (0, 0, −1).
enum GradeMath {

    /// Elevation of the camera's line of sight above the horizon, in degrees.
    /// Positive = looking uphill. Independent of how the phone is rolled.
    ///
    /// The camera axis is c = (0, 0, −1) and "up" is −g, so
    /// sin(elevation) = c · (−g) = g.z. We use atan2 for numerical stability.
    static func elevationDegrees(gx: Double, gy: Double, gz: Double) -> Double {
        let horizontal = (gx * gx + gy * gy).squareRoot()
        return atan2(gz, horizontal) * 180 / .pi
    }

    /// Sideways tilt (roll) of the phone, in degrees. 0 = held plumb.
    /// Positive when the right edge of the phone is lower.
    static func rollDegrees(gx: Double, gy: Double) -> Double {
        atan2(gx, -gy) * 180 / .pi
    }

    /// Percent grade (rise / run × 100) for an angle in degrees.
    static func percentGrade(fromDegrees degrees: Double) -> Double {
        tan(degrees * .pi / 180) * 100
    }

    /// Angle in degrees for a percent grade.
    static func degrees(fromPercent percent: Double) -> Double {
        atan(percent / 100) * 180 / .pi
    }

    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = mean(values)
        let variance = values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count - 1)
        return variance.squareRoot()
    }
}
