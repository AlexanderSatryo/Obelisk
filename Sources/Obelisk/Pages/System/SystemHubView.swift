import SwiftUI

/// Renders the Hardware & Battery Telemetry module inside the expanded Obelisk dashboard.
/// Features a streamlined horizontal layout with vertical divider lines separating metrics instead of bento cards.
public struct SystemHubView: View {
    @ObservedObject var telemetry: HardwareTelemetryService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared

    public init() {}

    public var body: some View {
        let cpuColor = telemetry.cpuUsagePercent > 80
            ? settings.resolvedColor(for: .battery(isLow: true))
            : settings.resolvedColor(for: .cpu)
        let memColor = telemetry.memoryUsagePercent > 85
            ? settings.resolvedColor(for: .battery(isLow: true))
            : settings.resolvedColor(for: .memory)
        let batColor = settings.resolvedColor(for: .battery(isLow: telemetry.batteryPercentage <= 20))
        let storageColor = settings.resolvedColor(for: .storage)

        VStack(spacing: 12) {
            // Hardware Telemetry Row separated by vertical divider lines
            HStack(spacing: 0) {
                // 1. CPU Load Column
                TelemetryMetricColumn(
                    title: "CPU LOAD",
                    primaryValue: "\(Int(round(telemetry.cpuUsagePercent)))%",
                    subtitle: "Thermal: \(telemetry.thermalStateLabel)",
                    iconName: "cpu.fill",
                    accentColor: cpuColor,
                    progress: telemetry.cpuUsagePercent / 100.0
                )

                metricDivider

                // 2. Unified Memory (RAM) Column
                TelemetryMetricColumn(
                    title: "MEMORY",
                    primaryValue: String(format: "%.1f GB", telemetry.memoryUsedGB),
                    subtitle: String(format: "of %.0f GB • %@", telemetry.memoryTotalGB, telemetry.memoryPressureLabel),
                    iconName: "memorychip.fill",
                    accentColor: memColor,
                    progress: telemetry.memoryUsagePercent / 100.0
                )

                metricDivider

                // 3. Battery & MagSafe Power Column
                let batSubtitle: String = {
                    if telemetry.isCharging {
                        if let mins = telemetry.timeRemainingMinutes, mins > 0 {
                            let h = mins / 60
                            let m = mins % 60
                            return h > 0 ? "\(h)h \(m)m until full" : "\(m)m until full"
                        } else if telemetry.batteryPercentage >= 100 {
                            return "Fully Charged"
                        } else {
                            return "Calculating..."
                        }
                    } else if telemetry.isPluggedIn {
                        return "Power Adapter"
                    } else {
                        if let mins = telemetry.timeRemainingMinutes, mins > 0 {
                            let h = mins / 60
                            let m = mins % 60
                            return "\(h > 0 ? "\(h)h \(m)m" : "\(m)m") Left"
                        }
                        return "On Battery"
                    }
                }()

                TelemetryMetricColumn(
                    title: telemetry.isCharging ? "CHARGING" : (telemetry.isPluggedIn ? "AC POWER" : "BATTERY"),
                    primaryValue: "\(telemetry.batteryPercentage)%",
                    subtitle: batSubtitle,
                    customIcon: AnyView(
                        BatteryPillBadge(
                            percentage: telemetry.batteryPercentage,
                            isCharging: telemetry.isCharging
                        )
                        .scaleEffect(0.85)
                    ),
                    accentColor: batColor,
                    progress: Double(telemetry.batteryPercentage) / 100.0
                )

                metricDivider

                // 4. SSD Storage Column
                TelemetryMetricColumn(
                    title: "STORAGE",
                    primaryValue: String(format: "%.0f GB", telemetry.diskFreeGB),
                    subtitle: "Available Free",
                    iconName: "internaldrive.fill",
                    accentColor: storageColor,
                    progress: telemetry.diskUsagePercent / 100.0
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            // Subtle Footer Summary Bar (without dot next to Battery Health)
            HStack(spacing: 14) {
                Text("Battery Health: \(telemetry.batteryHealthPercent)%")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                if telemetry.batteryCycleCount > 0 {
                    Text("•")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.25))

                    Text("Cycles: \(telemetry.batteryCycleCount)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .brightness((settings.colorBrightness - 1.0) * 0.40)
        .onAppear {
            telemetry.updateAllMetrics(isInitial: false)
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: max(48, 48.0 + CGFloat(settings.expandedHeightOffset * 0.45)))
            .padding(.horizontal, 6)
    }
}

/// Clean hardware metric column separated by single vertical divider lines.
struct TelemetryMetricColumn: View {
    let title: String
    let primaryValue: String
    let subtitle: String
    var iconName: String? = nil
    var customIcon: AnyView? = nil
    let accentColor: Color
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let custom = customIcon {
                    custom
                } else if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundColor(accentColor)
                }
                Text(title)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.5)
                    .lineLimit(1)
            }

            Text(primaryValue)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 3)
                    Capsule()
                        .fill(accentColor.opacity(0.90))
                        .frame(
                            width: max(3, min(geo.size.width, geo.size.width * CGFloat(progress))),
                            height: 3
                        )
                }
            }
            .frame(height: 3)

            Text(subtitle)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
