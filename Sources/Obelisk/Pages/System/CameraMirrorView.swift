import SwiftUI
import AppKit
import AVFoundation

/// `NSViewRepresentable` wrapper around `AVCaptureVideoPreviewLayer` with horizontal mirror flip.
public struct MirroredCameraPreviewRepresentable: NSViewRepresentable {
    public let session: AVCaptureSession
    public let isZoomedIn: Bool

    public func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.setSession(session)
        view.setZoom(isZoomedIn)
        return view
    }

    public func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.setSession(session)
        nsView.setZoom(isZoomedIn)
    }
}

/// Custom `NSView` hosting a horizontally mirrored `AVCaptureVideoPreviewLayer`.
public final class CameraPreviewNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setSession(_ session: AVCaptureSession) {
        if previewLayer.session !== session {
            previewLayer.session = session
        }
    }

    public func setZoom(_ zoomed: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        let scale: CGFloat = zoomed ? 1.28 : 1.0
        previewLayer.transform = CATransform3DMakeScale(-scale, scale, 1.0)
        previewLayer.frame = bounds
        CATransaction.commit()
    }

    override public func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }
}

/// Clean, minimalist Quick Camera Mirror viewport displayed inside the expanded Obelisk Notch.
public struct CameraMirrorView: View {
    @ObservedObject var mirrorService: CameraMirrorService = .shared

    public init() {}

    public var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)

                MirroredCameraPreviewRepresentable(
                    session: mirrorService.captureSession,
                    isZoomedIn: mirrorService.isZoomedIn
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Minimalist Top Controls (Zoom & Close)
                HStack(spacing: 6) {
                    Text(mirrorService.activeCameraName)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())

                    Spacer()

                    Button(action: {
                        mirrorService.isZoomedIn.toggle()
                    }) {
                        Text(mirrorService.isZoomedIn ? "1.3x" : "1.0x")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            mirrorService.stopMirror()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 20, height: 20)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }
            .frame(height: 152)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }
}
