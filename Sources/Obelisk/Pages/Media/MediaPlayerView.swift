import SwiftUI

/// Renders the custom vector Audio Output Speaker icon matching the reference design
/// (left screen bracket with stand + right hi-fi speaker enclosure with tweeter and woofer).
public struct AudioOutputSpeakerIconView: View {
    public var color: Color = .white.opacity(0.75)

    public init(color: Color = .white.opacity(0.75)) {
        self.color = color
    }

    public var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // 1. Left Screen Bracket (open on the right where speaker sits)
            var bracket = Path()
            bracket.move(to: CGPoint(x: w * 0.34, y: h * 0.18))
            bracket.addLine(to: CGPoint(x: w * 0.16, y: h * 0.18))
            bracket.addQuadCurve(
                to: CGPoint(x: w * 0.08, y: h * 0.26),
                control: CGPoint(x: w * 0.08, y: h * 0.18)
            )
            bracket.addLine(to: CGPoint(x: w * 0.08, y: h * 0.62))
            bracket.addQuadCurve(
                to: CGPoint(x: w * 0.16, y: h * 0.70),
                control: CGPoint(x: w * 0.08, y: h * 0.70)
            )
            bracket.addLine(to: CGPoint(x: w * 0.34, y: h * 0.70))
            ctx.stroke(
                bracket,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
            )

            // 2. Left Screen Base Stand Line
            var stand = Path()
            stand.move(to: CGPoint(x: w * 0.22, y: h * 0.84))
            stand.addLine(to: CGPoint(x: w * 0.34, y: h * 0.84))
            ctx.stroke(
                stand,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.35, lineCap: .round)
            )

            // 3. Right Speaker Box Enclosure
            let speakerRect = CGRect(
                x: w * 0.44,
                y: h * 0.12,
                width: w * 0.48,
                height: h * 0.76
            )
            let speakerPath = Path(roundedRect: speakerRect, cornerRadius: 2.6)
            ctx.stroke(
                speakerPath,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.35, lineJoin: .round)
            )

            // 4. Upper Tweeter Dot inside Speaker Box
            let tweeterRadius: CGFloat = min(w, h) * 0.065
            let tweeterCenter = CGPoint(x: speakerRect.midX, y: speakerRect.minY + speakerRect.height * 0.30)
            let tweeterRect = CGRect(
                x: tweeterCenter.x - tweeterRadius,
                y: tweeterCenter.y - tweeterRadius,
                width: tweeterRadius * 2,
                height: tweeterRadius * 2
            )
            ctx.fill(Path(ellipseIn: tweeterRect), with: .color(color))

            // 5. Lower Woofer Circle inside Speaker Box
            let wooferRadius: CGFloat = min(w, h) * 0.135
            let wooferCenter = CGPoint(x: speakerRect.midX, y: speakerRect.minY + speakerRect.height * 0.67)
            let wooferRect = CGRect(
                x: wooferCenter.x - wooferRadius,
                y: wooferCenter.y - wooferRadius,
                width: wooferRadius * 2,
                height: wooferRadius * 2
            )
            ctx.fill(Path(ellipseIn: wooferRect), with: .color(color))
        }
        .frame(width: 15, height: 14)
    }
}

/// Renders the primary media playback card inside the expanded Obelisk dashboard (Left Column).
/// Follows the exact layout from the reference design:
/// - Top: Artwork + Title + Artist
/// - Middle: Scrubber bar with a single running (elapsed) time label
/// - Bottom: Lyrics bubble toggle, Transport controls, and Audio Output Speaker
public struct MediaPlayerView: View {
    @ObservedObject var mediaManager: MediaManager = .shared
    @ObservedObject var audioService: AudioPeripheralsService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared
    @State private var isHoveringBar: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var scrubTargetSeconds: Double = 0
    @State private var hoveredControl: String? = nil

    private var displayedProgress: Double {
        guard mediaManager.currentTrack.duration > 0 else { return 0 }
        let pos = isScrubbing ? scrubTargetSeconds : mediaManager.currentTrack.position
        return min(max(pos / mediaManager.currentTrack.duration, 0), 1.0)
    }

    private var displayedFormattedPosition: String {
        let sec = isScrubbing ? scrubTargetSeconds : mediaManager.currentTrack.position
        let total = Int(max(sec, 0))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private var displayedFormattedRemaining: String {
        guard mediaManager.currentTrack.duration > 0 else { return "--:--" }
        let sec = isScrubbing ? scrubTargetSeconds : mediaManager.currentTrack.position
        let rem = max(mediaManager.currentTrack.duration - sec, 0)
        let total = Int(round(rem))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        if hours > 0 {
            return String(format: "-%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "-%02d:%02d", minutes, remainder)
    }

    private var isVideo: Bool {
        mediaManager.currentTrack.source == .youtube || mediaManager.currentTrack.source == .vidio
    }

    private var appLogoColor: Color {
        switch mediaManager.currentTrack.source {
        case .spotify:
            return Color(red: 30/255, green: 215/255, blue: 96/255)
        case .vidio:
            return Color(red: 237/255, green: 30/255, blue: 71/255)
        case .youtube:
            return Color(red: 255/255, green: 0/255, blue: 0/255)
        case .appleMusic:
            return Color(red: 250/255, green: 36/255, blue: 60/255)
        case .bein:
            return Color(red: 165/255, green: 70/255, blue: 210/255)
        default:
            return settings.resolvedColor(for: .mediaAccent(source: mediaManager.currentTrack.source))
        }
    }

    private var progressBarColor: Color {
        if settings.waveformColorMode == .monochromeWhite || settings.colorTheme == .monochrome {
            return Color.white.opacity(0.85)
        }
        // Requirement: Untuk lagu, warna bar nya mengikuti warna dari album lagu tersebut
        if !isVideo, let artColor = mediaManager.artworkAccentColor {
            return artColor
        }
        return appLogoColor
    }

    private var accentColor: Color {
        progressBarColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Artwork + Track Details (Title & Artist)
            HStack(spacing: 10) {
                // Artwork thumbnail
                ZStack {
                    if let image = mediaManager.artworkImage {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: Color.black.opacity(0.35), radius: 5, y: 2)
                    } else if let logo = mediaManager.sourceLogoImage {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 44, height: 44)

                            Image(nsImage: logo)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 26, height: 26)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .shadow(color: Color.black.opacity(0.35), radius: 5, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.35))
                            )
                    }
                }

                // Title, Source Badge & Artist
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(mediaManager.currentTrack.title.isEmpty ? "No Media Playing" : mediaManager.currentTrack.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if mediaManager.currentTrack.source != .none {
                            SourceLogoView(source: mediaManager.currentTrack.source, size: 13)
                        }

                        Spacer(minLength: 0)
                    }

                    Text(mediaManager.currentTrack.artist.isEmpty ? "Obelisk Media" : mediaManager.currentTrack.artist)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Row 2: Elapsed (running) time + Scrubber Bar + Remaining time
            let timeLabelWidth: CGFloat = (mediaManager.currentTrack.duration >= 3600) ? 48 : 38
            HStack(spacing: 8) {
                Text(displayedFormattedPosition)
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: timeLabelWidth, alignment: .leading)

                // Interactive Click & Drag Scrubber Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Color.clear
                            .frame(height: 14)

                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: (isHoveringBar || isScrubbing) ? 4.5 : 3)

                        Capsule()
                            .fill(accentColor)
                            .frame(
                                width: max(0, min(geo.size.width, geo.size.width * CGFloat(displayedProgress))),
                                height: (isHoveringBar || isScrubbing) ? 4.5 : 3
                            )

                        if (isHoveringBar || isScrubbing) && mediaManager.currentTrack.duration > 0 {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .offset(x: max(0, min(geo.size.width - 8, geo.size.width * CGFloat(displayedProgress) - 4)))
                                .shadow(color: Color.black.opacity(0.4), radius: 2)
                        }
                    }
                    .contentShape(Rectangle())
                    .pointingHandCursor()
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            isHoveringBar = hovering
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard mediaManager.currentTrack.duration > 0 else { return }
                                let clampedX = max(0, min(value.location.x, geo.size.width))
                                let ratio = clampedX / geo.size.width
                                scrubTargetSeconds = ratio * mediaManager.currentTrack.duration
                                isScrubbing = true
                            }
                            .onEnded { value in
                                guard mediaManager.currentTrack.duration > 0 else {
                                    isScrubbing = false
                                    return
                                }
                                let clampedX = max(0, min(value.location.x, geo.size.width))
                                let ratio = clampedX / geo.size.width
                                let finalSeconds = ratio * mediaManager.currentTrack.duration
                                isScrubbing = false
                                mediaManager.seek(to: finalSeconds)
                            }
                    )
                }
                .frame(height: 14)

                Text(displayedFormattedRemaining)
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: timeLabelWidth, alignment: .trailing)
            }

            // Row 3: Bottom Controls (Lyrics Button, Transport Controls, Audio Route Speaker)
            HStack(spacing: 0) {
                // Speech Bubble Lyrics Toggle Button (Left)
                if settings.showLyricsButton {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            settings.showLyricsInNotch.toggle()
                        }
                    }) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(settings.showLyricsInNotch ? .white : .white.opacity(0.35))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                } else {
                    Color.clear.frame(width: 24, height: 24)
                }

                Spacer()

                // Transport Controls (Center)
                HStack(spacing: 14) {
                    let isVideo = mediaManager.currentTrack.source == .youtube || mediaManager.currentTrack.source == .vidio
                    let skipSec = settings.skipIntervalSeconds

                    // Prev Button
                    let isPrevHovered = hoveredControl == "prev"
                    Button(action: {
                        if mediaManager.currentTrack.source == .youtube {
                            mediaManager.skipYouTube(seconds: -skipSec)
                        } else if mediaManager.currentTrack.source == .vidio {
                            mediaManager.skipVidio(seconds: -skipSec)
                        } else {
                            mediaManager.previousTrack()
                        }
                    }) {
                        Image(systemName: isVideo ? "gobackward.\(skipSec)" : "backward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isPrevHovered ? .white : .white.opacity(0.7))
                            .scaleEffect(isPrevHovered ? 1.08 : 1.0)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .onHover { h in
                        hoveredControl = h ? "prev" : nil
                    }

                    // Play / Pause Button
                    let isPlayHovered = hoveredControl == "play"
                    Button(action: {
                        mediaManager.togglePlayPause()
                    }) {
                        Image(systemName: mediaManager.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isPlayHovered ? .white : .white.opacity(0.9))
                            .scaleEffect(isPlayHovered ? 1.10 : 1.0)
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .onHover { h in
                        hoveredControl = h ? "play" : nil
                    }

                    // Next Button
                    let isNextHovered = hoveredControl == "next"
                    Button(action: {
                        if mediaManager.currentTrack.source == .youtube {
                            mediaManager.skipYouTube(seconds: skipSec)
                        } else if mediaManager.currentTrack.source == .vidio {
                            mediaManager.skipVidio(seconds: skipSec)
                        } else {
                            mediaManager.nextTrack()
                        }
                    }) {
                        Image(systemName: isVideo ? "goforward.\(skipSec)" : "forward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isNextHovered ? .white : .white.opacity(0.7))
                            .scaleEffect(isNextHovered ? 1.08 : 1.0)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    .onHover { h in
                        hoveredControl = h ? "next" : nil
                    }
                }

                Spacer()

                // Audio Output Speaker Button (Right)
                let isRouteHovered = hoveredControl == "speaker" || audioService.isRoutePickerExpanded
                Button(action: {
                    audioService.refreshAudioDevices()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        audioService.isRoutePickerExpanded.toggle()
                    }
                }) {
                    AudioOutputSpeakerIconView(
                        color: isRouteHovered ? .white : .white.opacity(0.65)
                    )
                    .scaleEffect(isRouteHovered ? 1.08 : 1.0)
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .onHover { h in
                    hoveredControl = h ? "speaker" : nil
                }
            }
        }
        .padding(.vertical, 1)
    }
}
