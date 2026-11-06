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
            return (sym, calmSkyBlue)
        case .deviceDisconnected(_, let icon, _):
            let sym = (icon == "download") ? "arrow.down.circle" : ((icon == "focus") ? "moon" : icon)
            return (sym, .white.opacity(0.55))
        case .battery(let pct, let isCharging, let statusText):
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
        }
    }

    private var cardTitle: String {
        switch hud {
        case .deviceConnected(let name, _, _), .deviceDisconnected(let name, _, _):
            return name
        case .battery(let pct, let isCharging, let statusText):
            if isCharging { return "Charging" }
            if statusText == "Disconnected" || statusText == "Unplugged" { return "Power Unplugged" }
            return pct <= 20 ? "Low Battery" : "Battery"
        case .volume(_, let isMuted):
            return isMuted ? "Muted" : "Volume"
        case .brightness:
            return "Brightness"
        }
    }

    private var cardSubtitle: String {
        switch hud {
        case .deviceConnected(_, _, let status), .deviceDisconnected(_, _, let status):
            return status
        case .battery(_, let isCharging, let statusText):
            if isCharging { return "Power Adapter Connected" }
            if statusText == "Disconnected" || statusText == "Unplugged" { return "Running on Battery" }
            return statusText
        case .volume(let level, let isMuted):
            return isMuted ? "Audio Output Muted" : "\(Int(round(level * 100)))%"
        case .brightness(let level):
            return "\(Int(round(level * 100)))%"
        }
    }

    @ViewBuilder
    private var cardTrailing: some View {
        switch hud {
        case .deviceConnected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(calmSageGreen)
        case .deviceDisconnected:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
        case .battery(let pct, let isCharging, let statusText):
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

    private var wingsBar: some View {
        let totalWidth = isExpanded ? WindowManager.shared.expandedSize.width : WindowManager.shared.compactWidth
        let topRowHeight = max(24, ScreenGeometry.notchSize.height + CGFloat(settings.compactHeightOffset))
        let notchWidth = ScreenGeometry.notchSize.width
        let wingWidth = max(0, (totalWidth - notchWidth) / 2.0)

        return HStack(spacing: 0) {
            if wingWidth >= 16 {
                HStack {
                    hudLeftWingContent(wingWidth: wingWidth)
                }
                .frame(width: wingWidth, alignment: .center)

                Spacer(minLength: notchWidth)

                HStack {
                    hudRightWingContent(wingWidth: wingWidth)
                }
                .frame(width: wingWidth, alignment: .center)
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
                BatteryPillBadge(percentage: pct, isCharging: isCharging)

                let title: String = {
                    if isCharging { return "Charging" }
                    if statusText == "Disconnected" || statusText == "Unplugged" { return "Unplugged" }
                    return pct <= 20 ? "Low Battery" : "Battery"
                }()

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

        case .deviceConnected(let name, let icon, _):
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 22, height: 22)
                    let sym = (icon == "download") ? "arrow.down.circle.fill" : ((icon == "focus") ? "moon.fill" : icon)
                    Image(systemName: sym)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(calmSkyBlue)
                }
                .frame(width: 22, height: 22)

                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

        case .deviceDisconnected(let name, let icon, _):
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 22, height: 22)
                    let sym = (icon == "download") ? "arrow.down.circle" : ((icon == "focus") ? "moon" : icon)
                    Image(systemName: sym)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
                .frame(width: 22, height: 22)

                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
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
            HStack(spacing: 4) {
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(isCharging ? calmSageGreen : (pct <= 20 ? calmWarmAmber : .white))

                let cleanSub = extractBatterySubtitle(statusText, pct: pct, isCharging: isCharging)
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

        case .deviceConnected(_, _, let statusText):
            HStack(spacing: 4) {
                Circle()
                    .fill(calmSageGreen)
                    .frame(width: 5, height: 5)
                Text(statusText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(calmSageGreen)
            }

        case .deviceDisconnected(_, _, let statusText):
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 5, height: 5)
                Text(statusText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
        }
    }

    private func extractBatterySubtitle(_ statusText: String, pct: Int, isCharging: Bool) -> String {
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
            return pct >= 100 ? "Fully Charged" : "Calculating..."
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

