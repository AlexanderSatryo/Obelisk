import SwiftUI

/// Renders the real-time synchronized karaoke lyrics in the Right Column of the Media dashboard.
/// Perfectly aligns with the Left Column Media Player, following the reference design:
/// - 3 synchronized vocal lines (previous line faded, current line bold white, next line faded)
/// - Left-aligned text typography
/// - Interactive line tap-to-seek
/// - Fallback waveform equalizer visualizer when lyrics are disabled or unavailable
public struct LyricsSideView: View {
    @ObservedObject var lyricsService: LyricsService = .shared
    @ObservedObject var mediaManager: MediaManager = .shared
    @ObservedObject var settings: ObeliskSettings = .shared
    @State private var hoveredLineId: UUID? = nil

    private var fontScale: CGFloat {
        settings.lyricsFontSizeScale.multiplier
    }

    private func scrollToActiveLine(proxy: ScrollViewProxy, animated: Bool = true) {
        let idx = lyricsService.activeLineIndex
        guard idx >= 0 && idx < lyricsService.lines.count else { return }
        let targetId = lyricsService.lines[idx].id
        if animated {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                proxy.scrollTo(targetId, anchor: .center)
            }
        } else {
            proxy.scrollTo(targetId, anchor: .center)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if lyricsService.isLoading {
                // Loading lyrics state
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.65)
                        .colorScheme(.dark)
                    Text("Searching lyrics...")
                        .font(.system(size: 11 * fontScale, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if lyricsService.hasLyrics && !lyricsService.lines.isEmpty {
                // Active Synced Lyrics Display (3-line karaoke scroll)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            // Top padding so the first line can center nicely
                            Spacer(minLength: 16)

                            ForEach(Array(lyricsService.lines.enumerated()), id: \.element.id) { index, line in
                                let isActive = (index == lyricsService.activeLineIndex)
                                let isHovered = (hoveredLineId == line.id)

                                Text(line.text)
                                    .font(.system(
                                        size: (isActive ? 13 : 11) * fontScale,
                                        weight: (isActive || isHovered) ? .bold : .regular
                                    ))
                                    .foregroundColor(
                                        isActive
                                            ? Color.white
                                            : (isHovered ? Color.white.opacity(0.85) : Color.white.opacity(0.40))
                                    )
                                    .shadow(
                                        color: isActive ? Color.white.opacity(0.35) : Color.clear,
                                        radius: isActive ? 4 : 0
                                    )
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 1)
                                    .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                    .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isActive)
                                    .id(line.id)
                                    .contentShape(Rectangle())
                                    .pointingHandCursor()
                                    .onHover { h in
                                        hoveredLineId = h ? line.id : nil
                                    }
                                    .onTapGesture {
                                        mediaManager.seek(to: line.time)
                                    }
                            }

                            // Bottom padding so the last line can center nicely
                            Spacer(minLength: 28)
                        }
                        .padding(.trailing, 12)
                    }
                    .frame(height: 96)
                    .clipped()
                    .onAppear {
                        scrollToActiveLine(proxy: proxy, animated: false)
                    }
                    .onChange(of: lyricsService.activeLineIndex) { _ in
                        scrollToActiveLine(proxy: proxy, animated: true)
                    }
                }
            } else {
                // Fallback calm label without visualizer
                Text("Instrumental")
                    .font(.system(size: 11 * fontScale, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
