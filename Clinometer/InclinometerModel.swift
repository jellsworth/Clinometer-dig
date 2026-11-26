import CoreMotion
import Foundation
import Observation

/// Reads the motion sensors and publishes the sighting angle.
///
/// - Smoothing: a light low-pass filter on the gravity vector for the live display.
/// - Steadiness: standard deviation of the unfiltered angle over the last ~0.5 s.
/// - Hold: freezes the reading as the *average* of that 0.5 s window, which is
///   more accurate than any single sample.
/// - Zero offset: corrects for the small misalignment between the camera's
///   optical axis and the motion sensor in your particular phone.
@Observable
final class InclinometerModel {

    // MARK: Published state

    private(set) var isAvailable = false
    /// Filtered elevation in degrees, before the zero offset is applied.
    private(set) var rawElevation: Double = 0
    private(set) var roll: Double = 0
    /// Standard deviation (degrees) of recent samples. Lower is steadier.
    private(set) var jitter: Double = 1
    /// Held reading in degrees (zero offset already applied), or nil when live.
    private(set) var heldElevation: Double?
    private(set) var zeroOffset: Double = 0

    // MARK: Derived

    var elevation: Double { heldElevation ?? (rawElevation - zeroOffset) }
    var grade: Double { GradeMath.percentGrade(fromDegrees: elevation) }
    var isHeld: Bool { heldElevation != nil }
    var isSteady: Bool { jitter < Self.steadyThreshold }

    // MARK: Tuning

    static let sampleRate: Double = 60
    static let smoothing: Double = 0.12          // low-pass factor per sample
    static let windowSize = 30                   // 0.5 s at 60 Hz
    static let steadyThreshold: Double = 0.15    // degrees
    private static let offsetKey = "zeroOffsetDegrees"

    // MARK: Internals

    private let manager = CMMotionManager()
    @ObservationIgnored private var filtered: SIMD3<Double>?
    @ObservationIgnored private var window: [Double] = []

    init() {
        zeroOffset = UserDefaults.standard.double(forKey: Self.offsetKey)
    }

    // MARK: Lifecycle

    func start() {
        isAvailable = manager.isDeviceMotionAvailable
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / Self.sampleRate
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.ingest(motion.gravity)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    // MARK: Actions

    func toggleHold() {
        if heldElevation != nil {
            heldElevation = nil
        } else {
            heldElevation = GradeMath.mean(window) - zeroOffset
        }
    }

    /// Call while sighting a mark known to be level with the lens
    /// (e.g. your calibrated point on an assistant standing on level ground).
    func setZeroFromCurrentSight() {
        zeroOffset = GradeMath.mean(window)
        UserDefaults.standard.set(zeroOffset, forKey: Self.offsetKey)
        heldElevation = nil
    }

    func clearZero() {
        zeroOffset = 0
        UserDefaults.standard.set(0.0, forKey: Self.offsetKey)
    }

    // MARK: Sample processing

    private func ingest(_ g: CMAcceleration) {
        let sample = SIMD3<Double>(g.x, g.y, g.z)

        let f: SIMD3<Double>
        if let previous = filtered {
            f = previous + (sample - previous) * Self.smoothing
        } else {
            f = sample
        }
        filtered = f

        let instant = GradeMath.elevationDegrees(gx: sample.x, gy: sample.y, gz: sample.z)
        window.append(instant)
        if window.count > Self.windowSize {
            window.removeFirst(window.count - Self.windowSize)
        }

        rawElevation = GradeMath.elevationDegrees(gx: f.x, gy: f.y, gz: f.z)
        roll = GradeMath.rollDegrees(gx: f.x, gy: f.y)
        jitter = GradeMath.standardDeviation(window)
    }
}
