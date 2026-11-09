import SwiftUI

/// A sleek, hardware-accelerated animated indeterminate progress bar matching macOS native aesthetics.
/// Used during streaming downloads or when the total download payload size is not exposed by the browser.
public struct IndeterminateProgressBar: View {
    public let width: CGFloat
    public let height: CGFloat

    @State private var phase: CGFloat = 0.0

    public init(width: CGFloat = 48, height: CGFloat = 4) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // Capsule track
            Capsule()
                .fill(Color.white.opacity(0.20))

            // Sweeping glowing bar indicator
            Capsule()
                .fill(Color.white)
                .frame(width: width * 0.42, height: height)
                .offset(x: phase * (width * 0.58))
        }
        .frame(width: width, height: height)
        .clipShape(Capsule())
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.1)
                .repeatForever(autoreverses: true)
            ) {
                phase = 1.0
            }
        }
    }
}

