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
        return showsExpanded
            ? min(1.0, max(0.15, settings.expandedOpacity))
            : min(1.0, max(0.15, settings.compactOpacity))
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
        let showDropShadow = showsExpanded && !windowManager.isCollapsing

        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                if showsExpanded {
                    // Expanded Dashboard (multi-tab: Media, Weather, Calendar, File, Notifications)
                    ExpandedNotchView(windowManager: windowManager)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                                removal: .opacity.animation(.easeOut(duration: 0.08))
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
            .brightness((settings.colorBrightness - 1.0) * 0.40)
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .background(notchBackgroundSurface)
            .clipShape(NotchShape(bottomRadius: currentRadius, topEarRadius: currentTopEarRadius))
            .overlay(notchBorderOverlay)
            .shadow(
                color: showDropShadow ? shadowColor : .clear,
                radius: showDropShadow ? 12 : 0,
                y: showDropShadow ? 6 : 0
            )
            .contentShape(NotchShape(bottomRadius: currentRadius, topEarRadius: currentTopEarRadius))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func surfaceBody(for style: NotchSurfaceStyle, isExpandedMode: Bool, isVisible: Bool) -> some View {
        switch style {
        case .pitchBlack:
            Color.black

        case .liquidGlass:
            NotchLiquidGlassSurface(
                bottomRadius: currentRadius,
                topEarRadius: currentTopEarRadius,
                blur: isExpandedMode ? settings.expandedGlassBlur : settings.compactGlassBlur,
                opacity: isExpandedMode ? settings.expandedOpacity : settings.compactOpacity,
                isExpanded: isExpandedMode,
                tint: nil,
                drawsBorder: false,
                isVisible: isVisible
            )

        case .darkGlass:
            NotchLiquidGlassSurface(
                bottomRadius: currentRadius,
                topEarRadius: currentTopEarRadius,
                blur: isExpandedMode ? settings.expandedGlassBlur : settings.compactGlassBlur,
                opacity: isExpandedMode ? settings.expandedOpacity : settings.compactOpacity,
                isExpanded: isExpandedMode,
                tint: Color.black.opacity(0.55),
                drawsBorder: false,
                isVisible: isVisible
            )

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
        let expOp = min(1.0, max(0.15, settings.expandedOpacity))
        let cmpOp = isNativeBlackStandbyHUD ? 1.0 : min(1.0, max(0.15, settings.compactOpacity))

        ZStack {
            // Persistent expanded material layer — never inserted/removed so its geometry always morphs in lockstep
            surfaceBody(
                for: expandedStyle,
                isExpandedMode: showsExpanded,
                isVisible: showsExpanded || compactStyle == expandedStyle
            )
            .opacity(showsExpanded ? expOp : (compactStyle == expandedStyle ? cmpOp : 0.0))

            // Persistent compact material layer (when distinct from expandedStyle) — morphs from expandedSize to compactSize smoothly
            if compactStyle != expandedStyle {
                surfaceBody(
                    for: compactStyle,
                    isExpandedMode: false,
                    isVisible: !showsExpanded
                )
                .opacity(showsExpanded ? 0.0 : cmpOp)
            }
        }
    }

    private var notchBorderOverlay: some View {
        let isGlass = activeSurfaceStyle.isLiquidGlass && !isNativeBlackStandbyHUD
        let op = isGlass ? (showsExpanded ? settings.expandedOpacity : settings.compactOpacity) : 0.0
        let showCustomBorder = settings.showBorder && !isNativeBlackStandbyHUD

        return ZStack {
            // Soft, harmonious 3D curved lens bevel refraction (always in view tree so path morphs without freezing)
            UnderNotchBorder(bottomRadius: currentRadius, topEarRadius: currentTopEarRadius)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.18 * op), location: 0.0),
                            .init(color: Color.white.opacity(0.04 * op), location: 0.35),
                            .init(color: Color.white.opacity(0.10 * op), location: 0.70),
                            .init(color: Color.white.opacity(0.16 * op), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.8
                )
                .blur(radius: 0.8)
                .opacity(isGlass ? 1.0 : 0.0)

            // Delicate, elegant outer glass rim that blends smoothly with the notch
            UnderNotchBorder(bottomRadius: currentRadius, topEarRadius: currentTopEarRadius)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.24 * op), location: 0.0),
                            .init(color: Color.white.opacity(0.08 * op), location: 0.40),
                            .init(color: Color.white.opacity(0.14 * op), location: 0.70),
                            .init(color: Color.white.opacity(0.20 * op), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
                .opacity(isGlass ? 1.0 : 0.0)

            // User-configurable hairline rim border
            UnderNotchBorder(bottomRadius: currentRadius, topEarRadius: currentTopEarRadius)
                .stroke(
                    borderStrokeColor,
                    lineWidth: CGFloat(showsExpanded ? settings.borderWidth : max(0.5, settings.borderWidth * 0.85))
                )
                .opacity(showCustomBorder ? 1.0 : 0.0)
        }
    }

    private var shadowColor: Color {
        guard showsExpanded else { return .clear }
        if activeSurfaceStyle == .ambientGlow && mediaManager.currentTrack.source != .none {
            return sourceAccentColor.opacity(0.32)
        }
        if activeSurfaceStyle == .liquidGlass {
            return Color.black.opacity(0.38)
        }
        return Color.black.opacity(0.55)
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
