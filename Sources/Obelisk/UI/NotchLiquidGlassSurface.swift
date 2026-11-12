import SwiftUI
import AppKit

/// Custom `NSVisualEffectView` subclass that masks its behind-window `CABackdropLayer`
/// to the exact `NotchShape` geometry on every layout pass, preventing rectangular ear blur leakage.
public final class MaskedVisualEffectView: NSVisualEffectView {
    public var bottomRadius: CGFloat = 14 {
        didSet {
            if abs(oldValue - bottomRadius) > 0.1 {
                updateNotchMask()
            }
        }
    }
    public var topEarRadius: CGFloat = 6 {
        didSet {
            if abs(oldValue - topEarRadius) > 0.1 {
                updateNotchMask()
            }
        }
    }
    private var lastMaskedSize: CGSize = .zero

    public override func layout() {
        super.layout()
        if bounds.size != lastMaskedSize {
            updateNotchMask()
        }
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if newSize != lastMaskedSize {
            updateNotchMask()
        }
    }

    public func updateNotchMask() {
        let size = bounds.size
        guard size.width > 2, size.height > 2 else { return }
        lastMaskedSize = size

        let bRad = bottomRadius
        let tRad = topEarRadius
        let img = NSImage(size: size, flipped: true) { rect in
            let cgPath = NotchShape(bottomRadius: bRad, topEarRadius: tRad).path(in: rect).cgPath
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.addPath(cgPath)
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fillPath()
            }
            return true
        }
        img.capInsets = NSEdgeInsetsZero
        self.maskImage = img
    }
}

/// Wraps AppKit's native `NSVisualEffectView` to deliver authentic Apple behind-window frosted glass blur
/// masked strictly to the `NotchShape` curve.
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    public var state: NSVisualEffectView.State = .active
    public var bottomRadius: CGFloat = 14
    public var topEarRadius: CGFloat = 6
    public var alpha: CGFloat = 1.0

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        bottomRadius: CGFloat = 14,
        topEarRadius: CGFloat = 6,
        alpha: CGFloat = 1.0
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.bottomRadius = bottomRadius
        self.topEarRadius = topEarRadius
        self.alpha = alpha
    }

    public func makeNSView(context: Context) -> MaskedVisualEffectView {
        let view = MaskedVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.bottomRadius = bottomRadius
        view.topEarRadius = topEarRadius
        view.alphaValue = alpha
        view.updateNotchMask()
        return view
    }

    public func updateNSView(_ nsView: MaskedVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.bottomRadius = bottomRadius
        nsView.topEarRadius = topEarRadius
        nsView.alphaValue = alpha
    }
}

/// Renders the notch body with Apple's Control Center / Dynamic Island Liquid Glass material:
/// - Real behind-window frosted optical blur (`NSVisualEffectView` with `.behindWindow`)
/// - Dynamic user-adjustable blur density and translucency (`notchOpacity`)
/// - 3D curved lens bevel refraction (soft inner glow along the perimeter)
/// - Crisp, luminous outer glass rim stroke
/// - Top horizontal specular highlight where glass meets the display bezel
public struct NotchLiquidGlassSurface: View {
    public var bottomRadius: CGFloat
    public var topEarRadius: CGFloat
    public var blur: Double
    public var opacity: Double
    public var isExpanded: Bool
    public var tint: Color?
    public var drawsBorder: Bool
    public var isVisible: Bool

    public init(
        bottomRadius: CGFloat,
        topEarRadius: CGFloat,
        blur: Double = 0.75,
        opacity: Double = 0.75,
        isExpanded: Bool = false,
        tint: Color? = nil,
        drawsBorder: Bool = false,
        isVisible: Bool = true
    ) {
        self.bottomRadius = bottomRadius
        self.topEarRadius = topEarRadius
        self.blur = blur
        self.opacity = opacity
        self.isExpanded = isExpanded
        self.tint = tint
        self.drawsBorder = drawsBorder
        self.isVisible = isVisible
    }

    private var resolvedMaterial: NSVisualEffectView.Material {
        if blur < 0.40 {
            return .underWindowBackground
        } else if blur < 0.75 {
            return .hudWindow
        } else {
            return .fullScreenUI
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // 1. Native Apple Behind-Window Frosted Blur (Refracts windows and desktop behind notch)
            VisualEffectBlur(
                material: resolvedMaterial,
                blendingMode: .behindWindow,
                bottomRadius: bottomRadius,
                topEarRadius: topEarRadius,
                alpha: isVisible ? CGFloat(min(1.0, max(0.15, opacity))) : 0.0
            )

            // 2. Optical Glass Translucent Wash with separated blur diffusion and body opacity
            ZStack {
                // Frosted light dispersion (controlled by blur density)
                Color.white.opacity(0.02 + 0.05 * blur)
                // Dark glass body tone (controlled by opacity)
                Color.black.opacity(0.12 + 0.38 * opacity)
                if let tint {
                    tint.opacity(0.30 * opacity)
                }
            }

            // 3. Apple 3D Glass Lens Specular Sheen (Refractive light beam from top-left to bottom-right)
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.20 * opacity), location: 0.0),
                    .init(color: Color.white.opacity(0.05 * opacity), location: 0.28),
                    .init(color: Color.clear, location: 0.60),
                    .init(color: Color.white.opacity(0.09 * opacity), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 4. Soft Top Ambient Light Falloff
            VStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.14 * opacity), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: isExpanded ? 32 : 16)
                Spacer()
            }

            if drawsBorder {
                // 5. Harmonious Inner Glass Bevel Refraction (soft 1.8pt, non-catchy)
                UnderNotchBorder(bottomRadius: bottomRadius, topEarRadius: topEarRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18 * opacity),
                                Color.white.opacity(0.04 * opacity),
                                Color.white.opacity(0.12 * opacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.8
                    )
                    .blur(radius: 0.8)

                // 6. Delicate Luminous Outer Glass Rim (subtle 0.75pt, perfectly integrated)
                UnderNotchBorder(bottomRadius: bottomRadius, topEarRadius: topEarRadius)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.26 * opacity), location: 0.0),
                                .init(color: Color.white.opacity(0.09 * opacity), location: 0.40),
                                .init(color: Color.white.opacity(0.15 * opacity), location: 0.75),
                                .init(color: Color.white.opacity(0.22 * opacity), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }

            // 7. Top Bezel Specular Highlight (where glass meets MacBook camera bezel)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28 * opacity),
                            Color.white.opacity(0.08 * opacity),
                            Color.white.opacity(0.28 * opacity)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.0)
        }
    }
}
