import Foundation
@preconcurrency import AVFoundation
import Combine

/// Manages the on-demand `AVCaptureSession` for the Quick Camera Mirror inside the Obelisk Notch.
/// Starts the built-in camera immediately when clicked and releases the hardware immediately when closed.
@MainActor
public final class CameraMirrorService: ObservableObject {
    public static let shared = CameraMirrorService()

    @Published public var isMirrorActive: Bool = false
    @Published public var isZoomedIn: Bool = false
    @Published public var activeCameraName: String = "Camera"

    public let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.alxstry.obelisk.cameramirror")
    private var isConfigured: Bool = false

    private init() {}

    /// Toggles the Quick Camera Mirror drawer open or closed and updates the notch container height.
    public func toggleMirror() {
        if isMirrorActive {
            stopMirror()
        } else {
            startMirror()
        }
    }

    /// Starts the front-camera mirror session immediately and expands the notch height to fit the preview.
    public func startMirror() {
        guard !isMirrorActive else { return }
        isMirrorActive = true
        WindowManager.shared.updateHeightForCurrentTab()

        // Request access if not yet determined, and start the session once authorized
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    Task { @MainActor in
                        self?.startSessionOnQueue()
                    }
                }
            }
        } else if status == .authorized {
            startSessionOnQueue()
        }
    }

    /// Stops the camera session immediately so the hardware indicator light turns off.
    public func stopMirror() {
        guard isMirrorActive else { return }
        isMirrorActive = false
        WindowManager.shared.updateHeightForCurrentTab()

        let session = self.captureSession
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func startSessionOnQueue() {
        let session = self.captureSession
        let alreadyConfigured = self.isConfigured

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !alreadyConfigured {
                session.beginConfiguration()
                session.sessionPreset = .high

                if let device = AVCaptureDevice.default(for: .video) {
                    let camName = device.localizedName
                    Task { @MainActor in
                        self.activeCameraName = camName
                    }
                    if let input = try? AVCaptureDeviceInput(device: device),
                       session.canAddInput(input) {
                        session.addInput(input)
                        Task { @MainActor in
                            self.isConfigured = true
                        }
                    }
                }
                session.commitConfiguration()
            }

            if !session.isRunning {
                session.startRunning()
            }
        }
    }
}
