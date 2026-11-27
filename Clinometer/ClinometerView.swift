import AVKit
import SwiftUI

struct ClinometerView: View {
    @State private var motion = InclinometerModel()
    @State private var camera = CameraController()
    @State private var showingZeroDialog = false
    @Environment(\.scenePhase) private var scenePhase

    private let zoomSteps: [CGFloat] = [1, 2, 4]

    var body: some View {
        GeometryReader { geo in
            let full = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let tapeHeight = min(320, full * 0.36)

            ZStack {
                // 1. Camera — the sighting scope.
                cameraLayer
                    .ignoresSafeArea()

                // 2. Scale drum, vertically centered on the line of sight.
                ScaleTapeView(elevation: motion.elevation)
                    .frame(width: 112, height: tapeHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)
                    .ignoresSafeArea()

                // 3. Reticle on top, so the hairline crosses the scale.
                ReticleView(roll: motion.roll, isHeld: motion.isHeld)
                    .ignoresSafeArea()

                // 4. Status strip and instrument panel.
                VStack(spacing: 0) {
                    statusStrip
                    Spacer()
                    instrumentPanel
                }
            }
        }
        .background(Theme.housing)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        // Volume buttons (and the Camera Control button) toggle HOLD,
        // so pressing the screen doesn't knock the phone off target.
        .onCameraCaptureEvent { event in
            if event.phase == .ended { motion.toggleHold() }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: motion.isHeld)
        .confirmationDialog("Zero calibration", isPresented: $showingZeroDialog, titleVisibility: .visible) {
            Button("Set zero on current sight") { motion.setZeroFromCurrentSight() }
            Button("Clear zero", role: .destructive) { motion.clearZero() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stand on level ground and aim at a mark at your lens height — your calibrated point on an assistant beside you, or your ribbon. That sight is defined as 0°.")
        }
        .onAppear(perform: start)
        .onDisappear(perform: stop)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { start() } else { stop() }
        }
    }

    // MARK: - Layers

    @ViewBuilder private var cameraLayer: some View {
        switch camera.status {
        case .running, .idle:
            CameraPreview(session: camera.session)
        case .denied:
            placeholder("CAMERA ACCESS OFF", "Enable camera access in Settings to use the sighting scope.")
        case .unavailable:
            placeholder("NO CAMERA", "The sighting scope needs a device with a rear camera.")
        }
    }

    private func placeholder(_ title: String, _ detail: String) -> some View {
        ZStack {
            Theme.housing
            VStack(spacing: 8) {
                Text(title).engravedLabel()
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.label)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
            // Shift content left so it doesn't overlap the scale drum
            // (112pt wide + 12pt trailing padding = ~124pt from right edge).
            .padding(.trailing, 128)
            .offset(y: -140)
        }
    }

    // MARK: - Status strip

    private var statusStrip: some View {
        HStack(spacing: 14) {
            indicator(
                label: motion.isHeld ? "HOLD" : (motion.isSteady ? "STEADY" : "SETTLING"),
                color: motion.isHeld ? Theme.accent : (motion.isSteady ? Theme.ok : Theme.warn)
            )
            Spacer()
            field("ROLL", String(format: "%4.1f°", abs(motion.roll)))
            field("ZERO", Format.signed(motion.zeroOffset, decimals: 2, width: 5) + "°")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.housing.opacity(0.82))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.bezelDark).frame(height: 1) }
    }

    private func indicator(label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 3)
            Text(label).engravedLabel(Theme.readout)
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label).engravedLabel()
            Text(value).font(Theme.mono(12, weight: .medium)).foregroundStyle(Theme.readout)
        }
    }

    // MARK: - Instrument panel

    private var instrumentPanel: some View {
        VStack(spacing: 14) {
            readouts
            controls
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            Theme.panel
                .overlay(alignment: .top) { Rectangle().fill(Theme.bezel).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var readouts: some View {
        let valueColor = motion.isHeld ? Theme.accent : Theme.readout
        let available = motion.isAvailable

        return HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grade").engravedLabel()
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(available ? Format.signed(motion.grade) : "--.-")
                        .font(Theme.mono(52, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(valueColor)
                    Text("%").font(Theme.mono(22)).foregroundStyle(Theme.label)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Angle").engravedLabel()
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(available ? Format.signed(motion.elevation) : "--.-")
                        .font(Theme.mono(28, weight: .medium))
                        .foregroundStyle(valueColor)
                    Text("°").font(Theme.mono(20)).foregroundStyle(Theme.label)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grade")
        .accessibilityValue(String(format: "%.1f percent, %.1f degrees", motion.grade, motion.elevation))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button { showingZeroDialog = true } label: {
                Text("Zero").frame(width: 64, height: 48)
            }
            .buttonStyle(InstrumentButtonStyle())

            HStack(spacing: 0) {
                ForEach(zoomSteps, id: \.self) { step in
                    let selected = abs(camera.zoom - step) < 0.01
                    Button { camera.setZoom(step) } label: {
                        Text("\(Int(step))×")
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(selected ? Theme.ink : Theme.readout)
                            .background(selected ? Theme.scale : Color.clear)
                    }
                }
            }
            .font(Theme.mono(14, weight: .semibold))
            .background(Theme.housing)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.bezel, lineWidth: 1))

            Button { motion.toggleHold() } label: {
                Text(motion.isHeld ? "Release" : "Hold")
                    .frame(width: 96, height: 48)
            }
            .buttonStyle(InstrumentButtonStyle(prominent: true, active: motion.isHeld))
        }
    }

    // MARK: - Lifecycle

    private func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        motion.start()
        camera.start()
    }

    private func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        motion.stop()
        camera.stop()
    }
}

/// Machined-looking button: dark face, light bezel, engraved caps label.
struct InstrumentButtonStyle: ButtonStyle {
    var prominent = false
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = active ? Theme.accent : (prominent ? Theme.bezelDark : Theme.housing)
        let text: Color = active ? Theme.ink : (prominent ? Theme.accent : Theme.readout)
        return configuration.label
            .font(Theme.mono(14, weight: .bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(text)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fill)
                    .brightness(configuration.isPressed ? 0.08 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(active ? Theme.accent : Theme.bezel, lineWidth: 1)
            )
    }
}

#Preview {
    ClinometerView()
}
