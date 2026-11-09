import SwiftUI

/// Renders the compact Dynamic Island state flanking the physical MacBook Pro notch.
/// When a device connects to the Mac (or charging state changes) while the notch is collapsed,
/// smoothly animates a compact status pill with icon, text, and subtle waveform below the camera bezel.
public struct CompactNotchView: View {
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var mediaManager: MediaManager = .shared
    @ObservedObject var weatherService: WeatherService = .shared
    @ObservedObject var telemetry: HardwareTelemetryService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared
    @ObservedObject var downloadService: DownloadMonitorService = .shared

    private var calmSkyBlue: Color {
        settings.resolvedColor(for: .cpu)
    }
    private var calmSageGreen: Color {
        settings.resolvedColor(for: .battery(isLow: false))
    }
    private var calmWarmAmber: Color {
        settings.resolvedColor(for: .battery(isLow: true))
    }

    private var hasTrack: Bool {
        let t = mediaManager.currentTrack
        return !t.title.isEmpty && t.title != "No Media Playing"
    }

    private var hasAlwaysActiveWingContent: Bool {
        let leftAlways = (settings.leftWingContent == .weatherMini || settings.leftWingContent == .batteryStatus || settings.leftWingContent == .cpuLoad)
        let rightAlways = (settings.rightWingStyle == .batteryOrPrivacy || settings.rightWingStyle == .systemTelemetry)
        return leftAlways || rightAlways
    }

    private var shouldShowWings: Bool {
        if settings.showDownloadsOnStandby && downloadService.isDownloading { return true }
        switch settings.compactWingMode {
        case .alwaysMinimal:
            return false
        case .alwaysWide:
            return true
        case .dynamicAuto:
            return hasTrack || hasAlwaysActiveWingContent
        }
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

    private var effectiveMediaColor: Color {
        if settings.waveformColorMode == .monochromeWhite || settings.colorTheme == .monochrome {
            return Color.white.opacity(0.85)
        }
        if !isVideo, let artColor = mediaManager.artworkAccentColor {
            return artColor
        }
        return appLogoColor
    }

    private var waveformColor: Color {
        effectiveMediaColor
    }

    private var timerColor: Color {
        if settings.compactTimerColorMode == .monochromeWhite {
            return Color.white.opacity(mediaManager.currentTrack.isPlaying ? 0.9 : 0.5)
        }
        return effectiveMediaColor.opacity(mediaManager.currentTrack.isPlaying ? 1.0 : 0.65)
    }

    private var formattedCompactPosition: String {
        let sec = Int(max(mediaManager.currentTrack.position, 0))
        let minutes = (sec % 3600) / 60
        let remainder = sec % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    public var body: some View {
        let totalWidth = windowManager.compactWidth
        let totalHeight = windowManager.compactHeight
        let topRowHeight = max(24, ScreenGeometry.notchSize.height + CGFloat(settings.compactHeightOffset))

        // Lebar bezel bawaan MacBook Pro M5 (185 pt safe area cutout):
        let bezelWidth = ScreenGeometry.notchSize.width
        let wingWidth = max(0, (totalWidth - bezelWidth) / 2.0)
        let earR = windowManager.activeCompactTopEarRadius
        let visibleBodyWidth = max(0, wingWidth - earR)

        HStack(spacing: 0) {
            if shouldShowWings && visibleBodyWidth >= 16 {
                Color.clear.frame(width: earR, height: topRowHeight)

                HStack {
                    leftWingView(wingWidth: visibleBodyWidth)
                }
                .frame(width: visibleBodyWidth, height: topRowHeight, alignment: .center)

                Color.clear.frame(width: bezelWidth, height: topRowHeight)

                HStack {
                    rightWingView
                }
                .frame(width: visibleBodyWidth, height: topRowHeight, alignment: .center)

                Color.clear.frame(width: earR, height: topRowHeight)
            }
        }
        .frame(width: totalWidth, height: topRowHeight)
        .frame(
            width: totalWidth,
            height: totalHeight,
            alignment: .top
        )
    }

    // MARK: - Standard Configurable Left Wing

    @ViewBuilder
    private func leftWingView(wingWidth: CGFloat) -> some View {
        if settings.showDownloadsOnStandby, let activeDownload = downloadService.activeDownloads.first {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(activeDownload.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: max(60, wingWidth - 20))
        } else {
            standardLeftWingContent
        }
    }

    @ViewBuilder
    private var standardLeftWingContent: some View {
        switch settings.leftWingContent {
        case .hidden:
            EmptyView()

        case .weatherMini:
            HStack(spacing: 2) {
                Image(systemName: weatherService.weather.iconName)
                    .font(.system(size: 10))
                    .symbolRenderingMode(settings.colorTheme == .monochrome ? .monochrome : .multicolor)
                    .foregroundColor(settings.resolvedColor(for: .weatherPrimary))
                Text("\(settings.convertedTemperature(weatherService.weather.temperature))°")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }

        case .batteryStatus:
            HStack(spacing: 2) {
                Image(systemName: telemetry.isCharging ? "bolt.fill" : "battery.100")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(telemetry.batteryPercentage <= 20 ? calmWarmAmber : calmSageGreen)
                Text("\(telemetry.batteryPercentage)%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }

        case .cpuLoad:
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(calmSkyBlue)
                Text("\(Int(round(telemetry.cpuUsagePercent)))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }

        case .sourceLogoOnly:
            if hasTrack {
                if let logo = mediaManager.sourceLogoImage {
                    Image(nsImage: logo)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    SourceLogoView(source: mediaManager.currentTrack.source, size: 17)
                }
            } else if settings.compactWingMode == .alwaysWide {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }

        case .artworkOrLogo:
            if hasTrack {
                if let image = mediaManager.artworkImage {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .shadow(color: Color.black.opacity(0.35), radius: 2)
                } else if let logo = mediaManager.sourceLogoImage {
                    Image(nsImage: logo)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    SourceLogoView(source: mediaManager.currentTrack.source, size: 17)
                }
            } else if settings.compactWingMode == .alwaysWide {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Standard Configurable Right Wing

    @ViewBuilder
    private var rightWingView: some View {
        if settings.showDownloadsOnStandby, let activeDownload = downloadService.activeDownloads.first {
            let frac = activeDownload.progressFraction ?? 0.0
            HStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 48, height: 4)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(4, min(48, 48 * CGFloat(frac))), height: 4)
                        .animation(.easeOut(duration: 0.28), value: frac)
                }
                .frame(width: 48, height: 4)

                Text("\(Int(round(frac * 100)))%")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        } else {
            standardRightWingContent
        }
    }

    @ViewBuilder
    private var standardRightWingContent: some View {
        switch settings.rightWingStyle {
        case .hidden:
            EmptyView()

        case .batteryOrPrivacy:
            HStack(spacing: 2) {
                if telemetry.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(calmSageGreen)
                }
                Text("\(telemetry.batteryPercentage)%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(telemetry.isCharging ? calmSageGreen : .white.opacity(0.85))
            }

        case .systemTelemetry:
            HStack(spacing: 2) {
                Circle()
                    .fill(calmSkyBlue)
                    .frame(width: 4.5, height: 4.5)
                Text("\(Int(round(telemetry.cpuUsagePercent)))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

        case .equalizerBars:
            if hasTrack || settings.compactWingMode == .alwaysWide {
                MiniWaveformView(
                    isPlaying: hasTrack && mediaManager.currentTrack.isPlaying,
                    color: waveformColor
                )
            }

        case .sineWave:
            if hasTrack || settings.compactWingMode == .alwaysWide {
                SineWaveformView(
                    isPlaying: hasTrack && mediaManager.currentTrack.isPlaying,
                    color: waveformColor
                )
            }

        case .minimalDots:
            if hasTrack || settings.compactWingMode == .alwaysWide {
                MinimalDotsWaveformView(
                    isPlaying: hasTrack && mediaManager.currentTrack.isPlaying,
                    color: waveformColor
                )
            }

        case .elapsedTimer:
            if hasTrack {
                CompactTimerWithProgressBar(
                    positionText: formattedCompactPosition,
                    timerColor: timerColor,
                    progressColor: effectiveMediaColor,
                    duration: mediaManager.currentTrack.duration,
                    position: mediaManager.currentTrack.position
                )
            } else if settings.compactWingMode == .alwaysWide {
                Text("0:00")
                    .font(.system(size: 9.5, weight: .semibold, design: .default))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

// MARK: - Compact Timer With Progress Bar

public struct CompactTimerWithProgressBar: View {
    public var positionText: String
    public var timerColor: Color
    public var progressColor: Color
    public var duration: Double
    public var position: Double

    @State private var textWidth: CGFloat = 22.0

    public init(
        positionText: String,
        timerColor: Color,
        progressColor: Color,
        duration: Double,
        position: Double
    ) {
        self.positionText = positionText
        self.timerColor = timerColor
        self.progressColor = progressColor
        self.duration = duration
        self.position = position
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 2.2) {
            Text(positionText)
                .font(.system(size: 9.5, weight: .semibold, design: .default))
                .foregroundColor(timerColor)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: CompactTimerWidthKey.self, value: geo.size.width)
                    }
                )

            if duration > 0 {
                let ratio = min(max(position / duration, 0), 1.0)
                let effectiveWidth = max(14, textWidth)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(0, min(effectiveWidth, effectiveWidth * CGFloat(ratio))))
                }
                .frame(width: effectiveWidth, height: 2.0)
            }
        }
        .onPreferenceChange(CompactTimerWidthKey.self) { newWidth in
            if newWidth > 0 && abs(newWidth - textWidth) > 0.5 {
                textWidth = newWidth
            }
        }
    }
}

public struct CompactTimerWidthKey: PreferenceKey {
    public static let defaultValue: CGFloat = 22.0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 4-Bar Animated Equalizer Waveform

/// Classic 4-bar vertical audio spectrum visualizer.
public struct MiniWaveformView: View {
    public var isPlaying: Bool
    public var color: Color = Color(red: 95/255, green: 190/255, blue: 130/255)

    public init(isPlaying: Bool, color: Color = Color(red: 95/255, green: 190/255, blue: 130/255)) {
        self.isPlaying = isPlaying
        self.color = color
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate * 6.5
            HStack(spacing: 2.2) {
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(color.opacity(isPlaying ? 1.0 : 0.45))
                    .frame(width: 2.4, height: isPlaying ? (4.0 + 8.0 * abs(sin(t))) : 4.5)

                RoundedRectangle(cornerRadius: 1.2)
                    .fill(color.opacity(isPlaying ? 1.0 : 0.45))
                    .frame(width: 2.4, height: isPlaying ? (5.0 + 10.0 * abs(sin(t + 1.2))) : 7.0)

                RoundedRectangle(cornerRadius: 1.2)
                    .fill(color.opacity(isPlaying ? 1.0 : 0.45))
                    .frame(width: 2.4, height: isPlaying ? (4.5 + 9.5 * abs(sin(t + 2.3))) : 5.5)

                RoundedRectangle(cornerRadius: 1.2)
                    .fill(color.opacity(isPlaying ? 1.0 : 0.45))
                    .frame(width: 2.4, height: isPlaying ? (4.0 + 7.5 * abs(sin(t + 3.4))) : 4.0)
            }
        }
        .frame(height: 18)
    }
}

// MARK: - Fluid Sine Wave Visualizer

/// Continuous oscillating harmonic sine curve rendered via SwiftUI `Canvas`.
public struct SineWaveformView: View {
    public var isPlaying: Bool
    public var color: Color

    public init(isPlaying: Bool, color: Color) {
        self.isPlaying = isPlaying
        self.color = color
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.04, paused: !isPlaying)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate * 7.5
            Canvas { ctx, size in
                var path = Path()
                let midY = size.height / 2.0
                let amplitude: CGFloat = isPlaying ? 5.2 : 1.5
                let width = size.width
                path.move(to: CGPoint(x: 0, y: midY))
                for x in stride(from: 0, through: width, by: 1.5) {
                    let norm = x / max(width, 1)
                    let envelope = sin(norm * .pi)
                    let y = midY + sin((norm * .pi * 2.5) + phase) * amplitude * envelope
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                ctx.stroke(
                    path,
                    with: .color(color.opacity(isPlaying ? 0.95 : 0.45)),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(width: 22, height: 16)
    }
}

// MARK: - Minimalist Pulse Dots Visualizer

/// Three synchronized pulsing dots that oscillate smoothly when media plays.
public struct MinimalDotsWaveformView: View {
    public var isPlaying: Bool
    public var color: Color

    public init(isPlaying: Bool, color: Color) {
        self.isPlaying = isPlaying
        self.color = color
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate * 5.8
            HStack(spacing: 3.5) {
                ForEach(0..<3, id: \.self) { idx in
                    let offset = isPlaying ? CGFloat(sin(t + Double(idx) * 1.1) * 3.2) : 0
                    let scale = isPlaying ? CGFloat(0.85 + 0.3 * abs(sin(t + Double(idx) * 1.1))) : 0.85
                    Circle()
                        .fill(color.opacity(isPlaying ? 0.95 : 0.45))
                        .frame(width: 4.2, height: 4.2)
                        .scaleEffect(scale)
                        .offset(y: offset)
                }
            }
        }
        .frame(height: 18)
    }
}
