import SwiftUI

public struct SourceLogoView: View {
    public let source: PlayerSource
    public var size: CGFloat = 16
    @ObservedObject var mediaManager: MediaManager = .shared

    public init(source: PlayerSource, size: CGFloat = 16) {
        self.source = source
        self.size = size
    }

    public var body: some View {
        Group {
            if let logoImage = mediaManager.sourceLogoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: size * 0.85, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }
}
