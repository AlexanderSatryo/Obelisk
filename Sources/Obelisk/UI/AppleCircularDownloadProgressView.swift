import SwiftUI

/// Apple-grade circular download progress indicator mimicking macOS Safari and iOS Dynamic Island.
/// Renders a crisp circular ring gauge that sweeps clockwise from 12 o'clock, smoothly filling up
/// to 100% (berputar sampai penuh) as the download progresses according to real speed and byte size.
public struct AppleCircularDownloadProgressView: View {
    public let progressFraction: Double?
    public let currentBytes: Int64
    public var tintColor: Color = .white

    public init(progressFraction: Double?, currentBytes: Int64 = 0, tintColor: Color = .white) {
        self.progressFraction = progressFraction
        self.currentBytes = currentBytes
        self.tintColor = tintColor
    }

    private var effectiveFraction: CGFloat {
        let raw = progressFraction ?? 0.05
        return CGFloat(max(0.04, min(1.0, raw)))
    }

    public var body: some View {
        HStack(spacing: 5.5) {
            // Apple Safari / iOS Dynamic Island circular progress ring
            ZStack {
                // Subtle outer circular track
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 2.2)

                // Smooth filling circular arc that starts at 12 o'clock and fills clockwise
                Circle()
                    .trim(from: 0, to: effectiveFraction)
                    .stroke(tintColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.32), value: effectiveFraction)
            }
            .frame(width: 15, height: 15)

            // Percentage readout
            let pct = Int(round(effectiveFraction * 100))
            Text("\(pct)%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}
