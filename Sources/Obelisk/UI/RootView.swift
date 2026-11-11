import SwiftUI

/// Primary unified morphing container for the Obelisk Notch.
/// Renders both the collapsed Dynamic Island wings and the expanded multi-tab dashboard
/// inside a single GPU-accelerated `NotchShape` container.
public struct RootView: View {
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var settings: ObeliskSettings = .shared
    @ObservedObject var mediaManager: MediaManager = .shared
    @ObservedObject var notificationService: NotificationService = .shared
    @ObservedObject var telemetry: HardwareTelemetryService = .shared
    @ObservedObject var downloadService: DownloadMonitorService = .shared

    private var showsExpanded: Bool {
        windowManager.isExpanded
    }

    private var currentWidth: CGFloat {
        showsExpanded ? windowManager.expandedSize.width : windowManager.compactWidth
    }

    private var currentHeight: CGFloat {
        showsExpanded ? windowManager.expandedSize.height : windowManager.compactHeight
    }

    private var isNativeBlackStandbyHUD: Bool {
        if !windowManager.isExpanded && notificationService.activeNotification != nil {
            return true
        }
        if !windowManager.isExpanded && settings.showDownloadsOnStandby && downloadService.isDownloading {
            return true
        }
        guard !windowManager.isExpanded,
              let hud = telemetry.activeTransientHUD else { return false }
        switch hud {
        case .volume, .brightness, .battery, .deviceConnected, .deviceDisconnected, .capsLock, .download, .scheduledAlert:
            return true
        }
    }

    private var currentRadius: CGFloat {
        if showsExpanded { return CGFloat(settings.expandedCornerRadius) }
        if isNativeBlackStandbyHUD {
            if settings.standbyHUDStyle == .horizontalWings {
                return CGFloat(settings.compactCornerRadius)
            } else {
                return 28.0
            }
        }
        return CGFloat(settings.compactCornerRadius)
    }

    private var currentTopEarRadius: CGFloat {
        if showsExpanded {
            return CGFloat(settings.expandedTopCornerRadius)
        }
        if isNativeBlackStandbyHUD && settings.standbyHUDStyle == .downwardCard {
            return min(12.0, CGFloat(settings.compactTopCornerRadius) + 1)
        }
        let baseWidth = ScreenGeometry.notchSize.width
        if windowManager.compactWidth > baseWidth + 4 {
            let extra = windowManager.compactWidth - baseWidth
            return min(CGFloat(settings.compactTopCornerRadius), extra * 0.25)
        }
        return 0.0
    }

    private var surfaceOpacity: Double {
        if isNativeBlackStandbyHUD {
            // 100% solid OLED pitch black like the physical MacBook camera housing
            return 1.0
        }
        return min(1.0, max(0.2, settings.notchOpacity))
    }

    private var activeSurfaceStyle: NotchSurfaceStyle {
        if showsExpanded {
            return settings.expandedSurfaceStyle
        }
        if isNativeBlackStandbyHUD {
            // Native pitch black like physical MacBook bezel
            return .pitchBlack
        }
        return settings.compactSurfaceStyle
    }

    private var sourceAccentColor: Color {
        settings.resolvedColor(for: .mediaAccent(source: mediaManager.currentTrack.source))
    }

    private var borderStrokeColor: Color {
        guard settings.showBorder else { return .clear }
        if isNativeBlackStandbyHUD {
            // Seamlessly merges with MacBook bezel without artificial border lines
            return .clear
        }
        let baseOpacity = windowManager.isExpanded
            ? settings.borderOpacity
            : max(0.04, settings.borderOpacity * 0.72)
        if activeSurfaceStyle == .ambientGlow && mediaManager.currentTrack.source != .none {
            return sourceAccentColor.opacity(min(0.55, baseOpacity * 2.2))
        }
        return Color.white.opacity(baseOpacity)
    }

    public var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                if showsExpanded {
                    // Expanded Dashboard (multi-tab: Media, Weather, Calendar, File, Notifications)
                    ExpandedNotchView(windowManager: windowManager)
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 0.96, anchor: .top)
                            )
                        )

                    // Transient HUD (earbuds, charging) rendered inside the top notch body
                    if let hud = telemetry.activeTransientHUD {
                        NotchTransientHUDBar(hud: hud, isExpanded: true)
                            .transition(.opacity)
                    }
                } else if let hud = telemetry.activeTransientHUD {
                    // Transient HUD (volume, mute, brightness, earbuds, charging) when collapsed in standby
                    NotchTransientHUDBar(hud: hud, isExpanded: false)
                        .transition(.opacity)
                } else if let notif = notificationService.activeNotification {
                    // Dynamic Island notification wings / unlocked card when collapsed
                    NotificationNotchView(notification: notif, windowManager: windowManager)
                        .transition(.opacity)
                } else {
                    // Compact Wings (visible when collapsed and transient HUD is not active)
                    CompactNotchView(windowManager: windowManager)
                        .opacity(telemetry.activeTransientHUD != nil ? 0 : 1)
                        .allowsHitTesting(telemetry.activeTransientHUD == nil)
                        .pointingHandCursor()
                        .onTapGesture {
                            guard !ScreenGeometry.isMissionControlActive() else { return }
                            if !windowManager.isExpanded && settings.triggerMode != .hoverOnly {
                                windowManager.expand()
                            }
                        }
                }
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .background(notchBackgroundSurface)
            .clipShape(NotchShape(bottomRadius: currentRadius, topEarRadius: currentTopEarRadius))
            .shadow(
                color: shadowColor,
                radius: showsExpanded ? 14 : 0,
                y: showsExpanded ? 7 : 0
            )
            .contentShape(NotchShape(bottomRadius: currentRadius, topEarRadius: currentTopEarRadius))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func surfaceBody(for style: NotchSurfaceStyle, isExpandedMode: Bool) -> some View {
        switch style {
        case .pitchBlack:
            Color.black

        case .liquidGlass:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.white.opacity(0.12)
                LinearGradient(
                    colors: [Color.white.opacity(0.32), Color.white.opacity(0.08), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

        case .darkGlass:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.65)
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.02), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

        case .frostedGlass:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(red: 14/255, green: 14/255, blue: 18/255).opacity(0.92)
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            }

        case .ambientGlow:
            ZStack {
                Color.black
                if mediaManager.currentTrack.source != .none {
                    LinearGradient(
                        colors: [
                            sourceAccentColor.opacity(isExpandedMode ? 0.20 : 0.10),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var notchBackgroundSurface: some View {
        let compactStyle = isNativeBlackStandbyHUD ? .pitchBlack : settings.compactSurfaceStyle
        let expandedStyle = settings.expandedSurfaceStyle

        ZStack {
            if compactStyle == expandedStyle {
                surfaceBody(for: expandedStyle, isExpandedMode: showsExpanded)
                    .opacity(surfaceOpacity)
            } else {
                // Crossfade smoothly between compact and expanded surface materials without pitch black delay
                surfaceBody(for: compactStyle, isExpandedMode: false)
                    .opacity(showsExpanded ? 0 : surfaceOpacity)
                surfaceBody(for: expandedStyle, isExpandedMode: true)
                    .opacity(showsExpanded ? surfaceOpacity : 0)
            }

            if settings.showBorder {
                UnderNotchBorder(bottomRadius: currentRadius, topEarRadius: currentTopEarRadius)
                    .stroke(
                        borderStrokeColor,
                        lineWidth: CGFloat(windowManager.isExpanded ? settings.borderWidth : max(0.5, settings.borderWidth * 0.85))
                    )
            }
        }
    }

    private var shadowColor: Color {
        guard showsExpanded else { return .clear }
        if activeSurfaceStyle == .ambientGlow && mediaManager.currentTrack.source != .none {
            return sourceAccentColor.opacity(0.32)
        }
        return Color.black.opacity(0.55)
    }
}

// MARK: - Liquid Glass Surface

/// Renders the notch body with Apple's ultra thin material blur and specular reflection gradient.
struct NotchLiquidGlassSurface: View {
    let shape: NotchShape
    let tint: Color?
    let opacity: Double

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            if let tint { tint }
            LinearGradient(
                colors: [Color.white.opacity(0.20), Color.white.opacity(0.04), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .opacity(opacity)
    }
}

// MARK: - Pointing Hand Cursor Modifier

public struct PointingHandModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .onHover { isInside in
                if isInside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

public extension View {
    func pointingHandCursor() -> some View {
        self.modifier(PointingHandModifier())
    }
}
