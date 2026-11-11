import SwiftUI

/// Renders transient status animations (Bluetooth earbuds connection, battery charging status)
/// directly inside the top notch body flanking the physical MacBook Pro camera housing.
/// Stays anchored inside the top notch body regardless of whether the notch is collapsed or expanded.
public struct NotchTransientHUDBar: View {
    let hud: NotchTransientHUD
    let isExpanded: Bool
    @ObservedObject var settings: ObeliskSettings = .shared

    private var calmSkyBlue: Color {
        settings.resolvedColor(for: .cpu)
    }
    private var calmSageGreen: Color {
        settings.resolvedColor(for: .battery(isLow: false))
    }
    private var calmWarmAmber: Color {
        settings.resolvedColor(for: .battery(isLow: true))
    }

    /// Height of the card that extends below the camera housing while the notch is collapsed.
    public static let extendedCardHeight: CGFloat = 72

    public var body: some View {
        if isExpanded {
            wingsBar
        } else {
            switch settings.standbyHUDStyle {
            case .horizontalWings:
                wingsBar
            case .downwardCard:
                extendedCard
            }
        }
    }

    // MARK: - Extended card (collapsed notch grows downward, like the AirPods connection card on iPhone)

    private var cardIcon: (name: String, color: Color) {
        switch hud {
        case .deviceConnected(_, let icon, _):
            let sym = (icon == "download") ? "arrow.down.circle.fill" : ((icon == "focus") ? "moon.fill" : icon)
            return (sym, .white)
        case .deviceDisconnected(_, let icon, _):
            let sym = (icon == "download") ? "arrow.down.circle" : ((icon == "focus") ? "moon" : icon)
            return (sym, .white.opacity(0.55))
        case .battery(let pct, let isCharging, let statusText):
            if statusText == "Fully Charged" || statusText.contains("Fully Charged") {
                return ("checkmark.circle.fill", calmSageGreen)
            }
            if isCharging { return ("bolt.fill", calmSageGreen) }
            if statusText == "Disconnected" || statusText == "Unplugged" { return ("powerplug", calmWarmAmber) }
            return (pct <= 20 ? "battery.25" : "battery.100", pct <= 20 ? calmWarmAmber : calmSageGreen)
        case .volume(let level, let isMuted):
            let iconName: String
            if isMuted {
                iconName = "speaker.slash.fill"
            } else if level <= 0.01 {
                iconName = "speaker.fill"
            } else if level < 0.33 {
                iconName = "speaker.wave.1.fill"
            } else if level < 0.66 {
                iconName = "speaker.wave.2.fill"
            } else {
                iconName = "speaker.wave.3.fill"
            }
            return (iconName, isMuted ? calmWarmAmber : Color.white)
        case .brightness:
            return ("sun.max.fill", Color(red: 255/255, green: 215/255, blue: 60/255))
        case .capsLock(let isOn):
            return (isOn ? "capslock.fill" : "capslock", isOn ? .white : .white.opacity(0.55))
        case .download(_, let statusText, let isSuccess, _):
            if isSuccess && (statusText == "Download Complete" || statusText.lowercased().contains("complete")) {
                return ("checkmark.circle.fill", calmSageGreen)
            } else if !isSuccess || statusText == "Download Failed" {
                return ("exclamationmark.triangle.fill", calmWarmAmber)
            } else {
                return ("arrow.down.circle", .white)
            }
        }
    }

    private var cardTitle: String {
        switch hud {
        case .deviceConnected(let name, _, _), .deviceDisconnected(let name, _, _):
            return name
        case .battery(let pct, let isCharging, let statusText):
            if statusText == "Fully Charged" || statusText.contains("Fully Charged") { return "Fully Charged" }
            if isCharging { return "Charging" }
            if statusText == "Disconnected" || statusText == "Unplugged" { return "Power Disconnected" }
            return pct <= 20 ? "Low Battery" : "Battery"
        case .volume(_, let isMuted):
            return isMuted ? "Muted" : "Volume"
        case .brightness:
            return "Brightness"
        case .capsLock:
            return "Caps Lock"
        case .download(let fileName, _, _, _):
            return fileName
        }
    }

    private var cardSubtitle: String {
        switch hud {
        case .deviceConnected(_, _, let status), .deviceDisconnected(_, _, let status):
            return status
        case .battery(_, let isCharging, let statusText):
            if statusText == "Fully Charged" || statusText.contains("Fully Charged") {
                return "Battery at 100% • Safe to unplug"
            }
            if isCharging { return "Power Adapter Connected" }
            if statusText == "Disconnected" || statusText == "Unplugged" { return "Running on Battery" }
            return statusText
        case .volume(let level, let isMuted):
            return isMuted ? "Audio Output Muted" : "\(Int(round(level * 100)))%"
        case .brightness(let level):
            return "\(Int(round(level * 100)))%"
        case .capsLock(let isOn):
            return isOn ? "Caps Lock is on" : "Caps Lock is off"
        case .download(_, let statusText, _, _):
            return statusText
        }
    }

    @ViewBuilder
    private var cardTrailing: some View {
        switch hud {
        case .deviceConnected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white)
        case .deviceDisconnected:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
        case .download(_, let statusText, let isSuccess, let progress):
            if let frac = progress, statusText != "Download Complete" && statusText != "Download Failed" {
                HStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.20))
                        Capsule().fill(Color.white)
                            .frame(width: max(4, min(56, 56 * CGFloat(frac))))
                            .animation(.linear(duration: 0.3), value: frac)
                    }
                    .frame(width: 56, height: 4)
                    Text("\(Int(round(frac * 100)))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
            } else if statusText == "Download Complete" || statusText == "Download Failed" {
                HStack(spacing: 5) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(isSuccess ? calmSageGreen : calmWarmAmber)
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSuccess ? .white : .white.opacity(0.75))
                }
            } else {
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
        case .battery(let pct, let isCharging, let statusText):
            if statusText == "Fully Charged" || statusText.contains("Fully Charged") {
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(calmSageGreen)
                        Text("100%")
                            .font(.system(size: 15, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }
                    Text("Complete")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(calmSageGreen)
                }
            } else {
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 4) {
                        if isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(calmSageGreen)
                        }
                        Text(statusText.contains("•") ? statusText : "\(pct)% • \(statusText)")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(isCharging ? calmSageGreen : (pct <= 20 ? calmWarmAmber : .white))
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Capsule()
                            .fill(isCharging ? calmSageGreen : (pct <= 20 ? calmWarmAmber : Color.white.opacity(0.8)))
                            .frame(width: 76 * CGFloat(max(0, min(100, pct))) / 100.0)
                    }
                    .frame(width: 76, height: 4)
                }
            }
        case .volume(let level, let isMuted):
            VStack(alignment: .trailing, spacing: 5) {
                Text(isMuted ? "Mute" : "\(Int(round(level * 100)))%")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .monospacedDigit()
                    .foregroundColor(isMuted ? calmWarmAmber : .white)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(isMuted ? calmWarmAmber : Color.white)
                        .frame(width: 76 * CGFloat(max(0, min(1.0, isMuted ? 0 : level))))
                        .animation(.interactiveSpring(response: 0.20, dampingFraction: 0.78), value: level)
                        .animation(.interactiveSpring(response: 0.20, dampingFraction: 0.78), value: isMuted)
                }
                .frame(width: 76, height: 4.5)
            }
        case .brightness(let level):
            VStack(alignment: .trailing, spacing: 5) {
                Text("\(Int(round(level * 100)))%")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .monospacedDigit()
                    .foregroundColor(.white)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(Color(red: 255/255, green: 215/255, blue: 60/255))
                        .frame(width: 76 * CGFloat(max(0, min(1.0, level))))
                        .animation(.interactiveSpring(response: 0.20, dampingFraction: 0.78), value: level)
                }
                .frame(width: 76, height: 4.5)
            }
        case .capsLock(let isOn):
            HStack(spacing: 5) {
                Circle()
                    .fill(isOn ? calmSageGreen : .white.opacity(0.35))
                    .frame(width: 6, height: 6)
                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(isOn ? calmSageGreen : .white.opacity(0.5))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(isOn ? calmSageGreen.opacity(0.15) : Color.white.opacity(0.08))
            )
        }
    }

    private var extendedCard: some View {
        let topRowHeight = max(24, ScreenGeometry.notchSize.height + CGFloat(settings.compactHeightOffset))
        let icon = cardIcon

        return VStack(spacing: 0) {
            // Clear band beside the physical camera housing
            Color.clear.frame(height: topRowHeight)

            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.10))
                    Image(systemName: icon.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(icon.color)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cardTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(cardSubtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                cardTrailing
            }
            .padding(.horizontal, 20)
            .frame(height: Self.extendedCardHeight - 8, alignment: .center)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Wings bar (used while in horizontal wings mode or while dashboard is expanded)

    private var isDownloadHUD: Bool {
        if case .download = hud { return true }
        return false
    }

    private var wingsBar: some View {
        let totalWidth = isExpanded ? WindowManager.shared.expandedSize.width : WindowManager.shared.compactWidth
        let topRowHeight = max(24, ScreenGeometry.notchSize.height + CGFloat(settings.compactHeightOffset))
        let bezelWidth = ScreenGeometry.notchSize.width
        let wingWidth = max(0, (totalWidth - bezelWidth) / 2.0)
        let earR = isExpanded ? CGFloat(settings.expandedTopCornerRadius) : WindowManager.shared.activeCompactTopEarRadius
        let visibleBodyWidth = max(0, wingWidth - earR)

        return HStack(spacing: 0) {
            if visibleBodyWidth >= 16 {
                Color.clear.frame(width: earR, height: topRowHeight)

                HStack {
                    hudLeftWingContent(wingWidth: visibleBodyWidth)
                }
                .frame(width: visibleBodyWidth, height: topRowHeight, alignment: .center)

                Color.clear.frame(width: bezelWidth, height: topRowHeight)

                HStack {
                    hudRightWingContent(wingWidth: visibleBodyWidth)
                }
                .frame(width: visibleBodyWidth, height: topRowHeight, alignment: .center)

                Color.clear.frame(width: earR, height: topRowHeight)
            }
        }
        .frame(width: totalWidth, height: topRowHeight)
    }

    @ViewBuilder
    private func hudLeftWingContent(wingWidth: CGFloat) -> some View {
        switch hud {
        case .volume(let level, let isMuted):
            HStack(spacing: 7) {
                VolumeBadge(level: level, isMuted: isMuted)
                Text(isMuted ? "Muted" : "Volume")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

        case .brightness:
            HStack(spacing: 7) {
                BrightnessBadge()
                Text("Brightness")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

        case .battery(let pct, let isCharging, let statusText):
            HStack(spacing: 7) {
                if statusText == "Fully Charged" || statusText.contains("Fully Charged") {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(calmSageGreen)

                    Text("Fully Charged")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else if statusText == "Disconnected" || statusText == "Unplugged" {
                    Image(systemName: "powerplug")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(calmWarmAmber)

                    Text("Disconnected")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    BatteryPillBadge(percentage: pct, isCharging: isCharging)

                    let title: String = {
                        if isCharging { return "Charging" }
                        return pct <= 20 ? "Low Battery" : "Battery"
                    }()

                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }

        case .deviceConnected(let name, let icon, _):
            HStack(spacing: 7) {
                let sym = (icon == "download") ? "arrow.down.circle.fill" : ((icon == "focus") ? "moon.fill" : icon)
                Image(systemName: sym)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

        case .deviceDisconnected(let name, let icon, _):
            HStack(spacing: 7) {
                let sym = (icon == "download") ? "arrow.down.circle" : ((icon == "focus") ? "moon" : icon)
                Image(systemName: sym)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))

                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }

        case .capsLock(let isOn):
            HStack(spacing: 7) {
                Image(systemName: isOn ? "capslock.fill" : "capslock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isOn ? .white : .white.opacity(0.65))

                Text("Caps Lock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

        case .download(let fileName, let statusText, let isSuccess, _):
            HStack(spacing: 6) {
                let iconName: String = {
                    if isSuccess && (statusText == "Download Complete" || statusText.lowercased().contains("complete")) {
                        return "checkmark.circle.fill"
                    } else if !isSuccess || statusText == "Download Failed" {
                        return "exclamationmark.circle.fill"
                    } else {
                        return "arrow.down.circle"
                    }
                }()
                let iconColor: Color = {
                    if isSuccess && (statusText == "Download Complete" || statusText.lowercased().contains("complete")) {
                        return calmSageGreen
                    } else if !isSuccess || statusText == "Download Failed" {
                        return calmWarmAmber
                    } else {
                        return .white
                    }
                }()
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(fileName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private func hudRightWingContent(wingWidth: CGFloat) -> some View {
        switch hud {
        case .volume(let level, let isMuted):
            let barW: CGFloat = 64
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(isMuted ? calmWarmAmber : Color.white)
                        .frame(width: max(0, min(barW, barW * CGFloat(isMuted ? 0 : level))))
                        .animation(.interactiveSpring(response: 0.20, dampingFraction: 0.78), value: level)
                        .animation(.interactiveSpring(response: 0.20, dampingFraction: 0.78), value: isMuted)
                }
                .frame(width: barW, height: 4)

                Text(isMuted ? "Mute" : "\(Int(round(level * 100)))%")
                    .font(.system(size: 10.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 36, alignment: .trailing)
            }

        case .brightness(let level):
            let barW: CGFloat = 64
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(Color(red: 255/255, green: 204/255, blue: 0/255))
                        .frame(width: max(0, min(barW, barW * CGFloat(level))))
                        .animation(.interactiveSpring(response: 0.20, dampingFraction: 0.78), value: level)
                }
                .frame(width: barW, height: 4)

                Text("\(Int(round(level * 100)))%")
                    .font(.system(size: 10.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 36, alignment: .trailing)
            }

        case .battery(let pct, let isCharging, let statusText):
            if statusText == "Fully Charged" || statusText.contains("Fully Charged") {
                HStack(spacing: 5) {
                    Text("100%")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(calmSageGreen)

                    Text("•")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))

                    Text("Unplug Charger")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 4) {
                    Text("\(pct)%")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(isCharging ? calmSageGreen : (pct <= 20 ? calmWarmAmber : .white))

                    let cleanSub = Self.extractBatterySubtitle(statusText, pct: pct, isCharging: isCharging)
                    if !cleanSub.isEmpty {
                        Text("•")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))

                        Text(cleanSub)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
            }

        case .deviceConnected(_, _, let statusText):
            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)

        case .deviceDisconnected(_, _, let statusText):
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.65))

        case .capsLock(let isOn):
            HStack(spacing: 5) {
                Circle()
                    .fill(isOn ? calmSageGreen : .white.opacity(0.35))
                    .frame(width: 5, height: 5)
                Text(isOn ? "On" : "Off")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isOn ? .white : .white.opacity(0.65))
            }

        case .download(_, let statusText, let isSuccess, let progress):
            if statusText != "Download Complete" && statusText != "Download Failed" {
                AppleCircularDownloadProgressView(
                    progressFraction: progress,
                    currentBytes: 0
                )
            } else if statusText == "Download Complete" || statusText == "Download Failed" {
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSuccess ? calmSageGreen : calmWarmAmber)
                    .lineLimit(1)
            } else {
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }

    public static func extractBatterySubtitle(_ statusText: String, pct: Int, isCharging: Bool) -> String {
        if statusText == "Disconnected" || statusText == "Unplugged" {
            return "On Battery"
        }
        if statusText.contains("•") {
            let parts = statusText.components(separatedBy: "•")
            if parts.count >= 2 {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        if isCharging {
            return pct >= 100 ? "Fully Charged" : "Charging"
        }
        return "On Battery"
    }
}

// MARK: - Bespoke Native Apple Components for Transient HUD

/// Pixel-perfect Apple-grade battery pill component with vector shell,
/// dynamic green/red fill, terminal cathode bump, and centered white lightning bolt.
public struct BatteryPillBadge: View {
    let percentage: Int
    let isCharging: Bool

    private var fillColor: Color {
        if isCharging {
            return Color(red: 52/255, green: 199/255, blue: 89/255) // Apple Battery Green
        }
        if percentage <= 20 {
            return Color(red: 255/255, green: 69/255, blue: 58/255) // Apple Battery Red
        }
        return Color.white
    }

    public var body: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                // Outer shell
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                    .frame(width: 23, height: 11.5)

                // Fill level
                let fillRatio = max(0.06, min(1.0, Double(percentage) / 100.0))
                RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                    .fill(fillColor)
                    .padding(2)
                    .frame(width: 23 * CGFloat(fillRatio), height: 11.5)

                // Crisp centered bolt when charging
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 0.5)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: 23, height: 11.5)

            // Cathode terminal bump
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.white.opacity(0.4))
                .frame(width: 1.5, height: 4.5)
        }
    }
}

/// Refined Apple-grade volume icon matching the notch UI.
public struct VolumeBadge: View {
    let level: Double
    let isMuted: Bool

    private var iconName: String {
        if isMuted {
            return "speaker.slash.fill"
        }
        if level <= 0.01 {
            return "speaker.fill"
        }
        if level < 0.33 {
            return "speaker.wave.1.fill"
        }
        if level < 0.66 {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
    }

    public var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundColor(isMuted ? Color(red: 255/255, green: 159/255, blue: 10/255) : .white)
    }
}

/// Refined Apple-grade brightness icon matching the notch UI.
public struct BrightnessBadge: View {
    public var body: some View {
        Image(systemName: "sun.max.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(red: 255/255, green: 204/255, blue: 0/255))
    }
}

