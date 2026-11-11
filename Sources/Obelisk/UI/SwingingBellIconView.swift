import SwiftUI

/// A bell glyph with a realistic pendulum swinging animation anchored at the top handle.
/// Used during scheduled alert triggers in both the standby notch and the alerts dashboard.
public struct SwingingBellIconView: View {
    public let size: CGFloat
    public let color: Color
    public let isAnimated: Bool

    @State private var isSwinging: Bool = false

    public init(
        size: CGFloat = 13,
        color: Color = Color(red: 255/255, green: 159/255, blue: 10/255),
        isAnimated: Bool = true
    ) {
        self.size = size
        self.color = color
        self.isAnimated = isAnimated
    }

    public var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .rotationEffect(.degrees(isAnimated && isSwinging ? 15 : -15), anchor: .top)
            .animation(
                isAnimated ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true) : .default,
                value: isSwinging
            )
            .onAppear {
                if isAnimated {
                    isSwinging = true
                }
            }
    }
}

