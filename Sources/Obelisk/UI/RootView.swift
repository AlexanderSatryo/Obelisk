import SwiftUI

/// Primary unified morphing container for the Obelisk Notch.
/// Renders both the collapsed Dynamic Island wings and the expanded multi-tab dashboard
/// inside a single GPU-accelerated `NotchShape` container.
public struct RootView: View {
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var settings: ObeliskSettings = .shared
    @ObservedObject var mediaManager: MediaManager = .shared
    @ObservedObject var notificationService: NotificationService = .shared

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
        guard !windowManager.isExpanded,
              let hud = HardwareTelemetryService.shared.activeTransientHUD else { return false }
        switch hud {
        case .volume, .brightness, .battery, .deviceConnected, .deviceDisconnected:
            return true
        }
    }

    private var currentRadius: CGFloat {
        if showsExpanded { return CGFloat(settings.expandedCornerRadius) }
        if notificationService.activeNotification != nil {
            return notificationService.isCardExpanded ? 28.0 : CGFloat(settings.compactCornerRadius)
        }
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
        if notificationService.activeNotification != nil && notificationService.isCardExpanded {
            return min(12.0, CGFloat(settings.compactTopCornerRadius) + 1)
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
                if let notif = notificationService.activeNotification {
                    NotificationNotchView(notification: notif, windowManager: windowManager)
                        .transition(.opacity)
                } else {
                    // Compact Wings (visible when collapsed and transient HUD is not active)
                    CompactNotchView(windowManager: windowManager)
                        .opacity((showsExpanded || HardwareTelemetryService.shared.activeTransientHUD != nil) ? 0 : 1)
                        .allowsHitTesting(!showsExpanded && HardwareTelemetryService.shared.activeTransientHUD == nil)

                    // Expanded Dashboard (smoothly fades & scales in from the top bezel)
                    if showsExpanded {
                        ExpandedNotchView(windowManager: windowManager)
                            .transition(
                                .opacity.combined(
                                    with: .scale(scale: 0.96, anchor: .top)
                                )
                            )
                    }

                    // Transient HUD (earbuds, charging) - ALWAYS rendered inside the top notch body, whether expanded or collapsed!
                    if let hud = HardwareTelemetryService.shared.activeTransientHUD {
                        NotchTransientHUDBar(hud: hud, isExpanded: showsExpanded)
                            .transition(.opacity)
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
            .pointingHandCursor()
            .onTapGesture {
                guard !ScreenGeometry.isMissionControlActive() else { return }
                if notificationService.activeNotification != nil {
                    if !notificationService.isCardExpanded {
                        notificationService.handleNotchTap()
                    }
                    return
                }
                if !windowManager.isExpanded && settings.triggerMode != .hoverOnly {
                    windowManager.expand()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var notchBackgroundSurface: some View {
        let shape = NotchShape(bottomRadius: currentRadius, topEarRadius: currentTopEarRadius)
        ZStack {
            switch activeSurfaceStyle {
            case .pitchBlack:
                Color.black.opacity(surfaceOpacity)

            case .liquidGlass:
                NotchLiquidGlassSurface(shape: shape, tint: nil, opacity: surfaceOpacity)

            case .darkGlass:
                NotchLiquidGlassSurface(shape: shape, tint: Color.black.opacity(0.55), opacity: surfaceOpacity)

            case .frostedGlass:
                ZStack {
                    Color(red: 13/255, green: 13/255, blue: 16/255).opacity(0.95)
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                }
                .opacity(surfaceOpacity)

            case .ambientGlow:
                ZStack {
                    Color.black
                    if mediaManager.currentTrack.source != .none {
                        LinearGradient(
                            colors: [
                                sourceAccentColor.opacity(windowManager.isExpanded ? 0.16 : 0.10),
                                Color.clear
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    }
                }
                .opacity(surfaceOpacity)
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

/// Renders the notch body with Apple's native Liquid Glass material on macOS 26 and later,
/// and falls back to a system blur material on earlier releases.
struct NotchLiquidGlassSurface: View {
    let shape: NotchShape
    let tint: Color?
    let opacity: Double

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                if let tint {
                    Color.clear.glassEffect(.regular.tint(tint), in: shape)
                } else {
                    Color.clear.glassEffect(.regular, in: shape)
                }
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    if let tint { tint }
                }
            }
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
