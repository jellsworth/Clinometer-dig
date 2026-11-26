import AVFoundation
import Observation
import SwiftUI
import UIKit

/// Owns the capture session. The camera is only a sighting scope:
/// nothing is recorded or saved.
@Observable
final class CameraController {

    enum Status { case idle, running, denied, unavailable }

    private(set) var status: Status = .idle
    private(set) var zoom: CGFloat = 1

    let session = AVCaptureSession()
    @ObservationIgnored private var device: AVCaptureDevice?
    private let queue = DispatchQueue(label: "clinometer.camera")

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.configureAndRun() } else { self.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// Zoom factor relative to the standard wide camera (1×).
    func setZoom(_ factor: CGFloat) {
        guard let device else { return }
        let upper = min(device.maxAvailableVideoZoomFactor, 10)
        let clamped = min(max(factor, device.minAvailableVideoZoomFactor), upper)
        zoom = clamped
        queue.async {
            do {
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: clamped, withRate: 8)
                device.unlockForConfiguration()
            } catch {
                // Zoom is a convenience; ignore failures.
            }
        }
    }

    private func configureAndRun() {
        if device != nil {
            queue.async {
                if !self.session.isRunning { self.session.startRunning() }
            }
            return
        }

        // The standard wide camera's optical axis is closest to the phone's
        // own axis, so we always sight through it and use digital zoom.
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            status = .unavailable
            return
        }
        device = camera

        queue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async { self.status = .running }
        }
    }
}

/// Live camera preview, filling its frame. The center of the view is the
/// center of the image, which is the line of sight.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
