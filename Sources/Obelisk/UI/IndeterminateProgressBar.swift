import SwiftUI

/// A sleek, hardware-accelerated animated progress bar matching macOS native aesthetics.
/// Sweeps strictly from left to right without reversing.
public struct IndeterminateProgressBar: View {
    public let width: CGFloat
    public let height: CGFloat

    @State private var phase: CGFloat = 0.0

    public init(width: CGFloat = 48, height: CGFloat = 4) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width
            let barHeight = geo.size.height
            let pillWidth = max(14, barWidth * 0.42)

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.20))

                // Indicator traveling strictly from left to right
                Capsule()
                    .fill(Color.white)
                    .frame(width: pillWidth, height: barHeight)
                    .offset(x: -pillWidth + (phase * (barWidth + pillWidth)))
            }
            .clipShape(Capsule())
        }
        .frame(width: width, height: height)
        .onAppear {
            phase = 0.0
            withAnimation(
                .linear(duration: 1.1)
                .repeatForever(autoreverses: false)
            ) {
                phase = 1.0
            }
        }
    }
}

