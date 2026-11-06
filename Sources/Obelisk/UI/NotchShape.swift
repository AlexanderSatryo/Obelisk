import SwiftUI

/// Draws the Apple Silicon Notch container with continuous curvature bottom corners
/// and smooth top ears (inverted fillets) that blend seamlessly into the physical MacBook screen bezel.
public struct NotchShape: Shape {
    public var bottomRadius: CGFloat = 14
    public var topEarRadius: CGFloat = 0

    public init(bottomRadius: CGFloat = 14, topEarRadius: CGFloat = 0) {
        self.bottomRadius = bottomRadius
        self.topEarRadius = topEarRadius
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, topEarRadius) }
        set {
            bottomRadius = newValue.first
            topEarRadius = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let R_top = max(0, min(topEarRadius, rect.height / 2, rect.width / 4))
        let R_bot = max(0, min(bottomRadius, rect.height / 2, rect.width / 4))

        // Start top-left touching the top screen bezel
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top edge touching bezel
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Top-right ear: flares smoothly from horizontal bezel down into vertical right edge with continuous G2 curvature
        if R_top > 0 {
            path.addCurve(
                to: CGPoint(x: rect.maxX - R_top, y: rect.minY + R_top),
                control1: CGPoint(x: rect.maxX - R_top * 0.44, y: rect.minY),
                control2: CGPoint(x: rect.maxX - R_top, y: rect.minY + R_top * 0.56)
            )
        }

        // Right vertical edge
        path.addLine(to: CGPoint(x: rect.maxX - R_top, y: rect.maxY - R_bot))

        // Bottom-right convex corner
        path.addArc(
            center: CGPoint(x: rect.maxX - R_top - R_bot, y: rect.maxY - R_bot),
            radius: R_bot,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom horizontal edge
        path.addLine(to: CGPoint(x: rect.minX + R_top + R_bot, y: rect.maxY))

        // Bottom-left convex corner
        path.addArc(
            center: CGPoint(x: rect.minX + R_top + R_bot, y: rect.maxY - R_bot),
            radius: R_bot,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left vertical edge
        path.addLine(to: CGPoint(x: rect.minX + R_top, y: rect.minY + R_top))

        // Top-left ear: flares smoothly from vertical left edge up into horizontal bezel with continuous G2 curvature
        if R_top > 0 {
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.minY),
                control1: CGPoint(x: rect.minX + R_top, y: rect.minY + R_top * 0.56),
                control2: CGPoint(x: rect.minX + R_top * 0.44, y: rect.minY)
            )
        }

        path.closeSubpath()
        return path
    }
}

/// Only strokes the left ear, left vertical edge, bottom corners, bottom edge, right vertical edge, and right ear.
/// Leaves the top horizontal edge completely open so it merges 100% seamlessly into the MacBook bezel without any line.
public struct UnderNotchBorder: Shape {
    public var bottomRadius: CGFloat = 14
    public var topEarRadius: CGFloat = 0

    public init(bottomRadius: CGFloat = 14, topEarRadius: CGFloat = 0) {
        self.bottomRadius = bottomRadius
        self.topEarRadius = topEarRadius
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, topEarRadius) }
        set {
            bottomRadius = newValue.first
            topEarRadius = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let R_top = max(0, min(topEarRadius, rect.height / 2, rect.width / 4))
        let R_bot = max(0, min(bottomRadius, rect.height / 2, rect.width / 4))

        // Start top-left touching bezel
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left ear: curves downward and rightward into vertical edge with continuous G2 curvature
        if R_top > 0 {
            path.addCurve(
                to: CGPoint(x: rect.minX + R_top, y: rect.minY + R_top),
                control1: CGPoint(x: rect.minX + R_top * 0.44, y: rect.minY),
                control2: CGPoint(x: rect.minX + R_top, y: rect.minY + R_top * 0.56)
            )
        }

        // Left vertical edge
        path.addLine(to: CGPoint(x: rect.minX + R_top, y: rect.maxY - R_bot))

        // Bottom-left convex corner
        path.addArc(
            center: CGPoint(x: rect.minX + R_top + R_bot, y: rect.maxY - R_bot),
            radius: R_bot,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Bottom horizontal edge
        path.addLine(to: CGPoint(x: rect.maxX - R_top - R_bot, y: rect.maxY))

        // Bottom-right convex corner
        path.addArc(
            center: CGPoint(x: rect.maxX - R_top - R_bot, y: rect.maxY - R_bot),
            radius: R_bot,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Right vertical edge
        path.addLine(to: CGPoint(x: rect.maxX - R_top, y: rect.minY + R_top))

        // Top-right ear: curves upward and rightward to meet bezel with continuous G2 curvature
        if R_top > 0 {
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control1: CGPoint(x: rect.maxX - R_top, y: rect.minY + R_top * 0.56),
                control2: CGPoint(x: rect.maxX - R_top * 0.44, y: rect.minY)
            )
        }

        return path
    }
}
