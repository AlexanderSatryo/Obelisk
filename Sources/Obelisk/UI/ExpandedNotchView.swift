import SwiftUI

/// Renders the expanded multi-page dashboard below the physical MacBook Pro notch bezel.
/// Supports instant tab switching across Media, Weather, Calendar, and System modules,
/// plus a one-click Quick Camera Mirror button in the header bar.
public struct ExpandedNotchView: View {
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var mediaManager: MediaManager = .shared
    @ObservedObject var lyricsService: LyricsService = .shared
    @ObservedObject var weatherService: WeatherService = .shared
    @ObservedObject var calendarService: CalendarService = .shared
    @ObservedObject var mirrorService: CameraMirrorService = .shared
    @ObservedObject var audioService: AudioPeripheralsService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared
    @ObservedObject var telemetry: HardwareTelemetryService = .shared

    @Namespace private var tabAnimation
    @State private var dragOffset: CGFloat = 0

    private var batteryStatusSubtitle: String {
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
            return telemetry.batteryPercentage >= 100 ? "Fully Charged" : "Power Adapter"
        } else {
            if let mins = telemetry.timeRemainingMinutes, mins > 0 {
                let h = mins / 60
                let m = mins % 60
                return "\(h > 0 ? "\(h)h \(m)m" : "\(m)m") Left"
            }
            return "On Battery"
        }
    }

    private var activeTabAccentColor: Color {
        if windowManager.currentTab == .media {
            if let artColor = mediaManager.artworkAccentColor {
                return artColor
            }
        }
        return Color(red: 0/255, green: 178/255, blue: 238/255)
    }

    private var topNotchClearance: CGFloat {
        let base: CGFloat = ScreenGeometry.hasPhysicalNotch ? (ScreenGeometry.notchSize.height + 14) : 16
        return max(6, base + CGFloat(settings.topNotchClearanceOffset))
    }

    /// Horizontal content inset that keeps every element clear of the flared top ears and curved bottom corners.
    private var contentInset: CGFloat {
        max(28, CGFloat(settings.expandedTopCornerRadius) + 16)
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                // Header bar placed completely below the physical MacBook Pro M5 notch
            HStack(spacing: 12) {
                Text("OBELISK")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(1.4)

                // Pure Floating Navigation Tabs (User's Icons + Active Accent Dot)
                HStack(spacing: 12) {
                    ForEach(settings.enabledTabs, id: \.rawValue) { tab in
                        let isSelected = windowManager.currentTab == tab
                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                windowManager.switchToTab(tab)
                            }
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.40))

                                if isSelected {
                                    Circle()
                                        .fill(activeTabAccentColor)
                                        .frame(width: 3.5, height: 3.5)
                                } else {
                                    Color.clear
                                        .frame(width: 3.5, height: 3.5)
                                }
                            }
                            .frame(height: 22)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                    }
                }
                .padding(.leading, 2)

                Spacer()

                // Pure Floating Battery & Charging Status (Zero background box)
                HStack(spacing: 5) {
                    BatteryPillBadge(
                        percentage: telemetry.batteryPercentage,
                        isCharging: telemetry.isCharging
                    )

                    Text("\(telemetry.batteryPercentage)%")
                        .font(.system(size: 10.5, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(
                            telemetry.isCharging
                                ? Color(red: 52/255, green: 199/255, blue: 89/255)
                                : (telemetry.batteryPercentage <= 20 ? Color(red: 255/255, green: 69/255, blue: 58/255) : .white)
                        )

                    let sub = batteryStatusSubtitle
                    if !sub.isEmpty {
                        Text("•")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))

                        Text(sub)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }

                // Pure Floating Header Actions (Camera & Settings, Arrow Removed)
                HStack(spacing: 10) {
                    // Quick Camera Mirror Toggle Button
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            mirrorService.toggleMirror()
                        }
                    }) {
                        Image(systemName: "web.camera")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(mirrorService.isMirrorActive ? .white : .white.opacity(0.60))
                            .frame(width: 20, height: 20)
                            .background(mirrorService.isMirrorActive ? Color.white.opacity(0.20) : Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()

                    // Settings button
                    Button(action: {
                        SettingsWindowManager.shared.showSettings()
                        windowManager.collapse()
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.60))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }
            .padding(.horizontal, contentInset)
            .padding(.top, topNotchClearance)

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, contentInset - 4)

            // Expandable Quick Camera Mirror Viewport
            if mirrorService.isMirrorActive {
                CameraMirrorView()
            }

            // Dynamic Tab Content with Trackpad Swipe & Drag
            ZStack {
                NotchPageView(tab: windowManager.currentTab)
                    .id(windowManager.currentTab)
                    .transition(.opacity.combined(with: .offset(x: 24)))
            }
            .padding(.horizontal, contentInset)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(x: dragOffset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        guard settings.enableHorizontalSwipe else { return }
                        dragOffset = value.translation.width * 0.4
                    }
                    .onEnded { value in
                        guard settings.enableHorizontalSwipe else {
                            dragOffset = 0
                            return
                        }
                        let threshold: CGFloat = 30
                        let invert = settings.invertHorizontalSwipe
                        if value.translation.width < -threshold {
                            windowManager.navigateTab(forward: invert ? true : false)
                        } else if value.translation.width > threshold {
                            windowManager.navigateTab(forward: invert ? false : true)
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            dragOffset = 0
                        }
                    }
            )

        }
        .frame(
            width: windowManager.expandedSize.width,
            height: windowManager.expandedSize.height,
            alignment: .top
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            let lock = NSLock()
            var found: [URL] = []
            let group = DispatchGroup()
            for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    defer { group.leave() }
                    var resolved: URL? = nil
                    if let data = item as? Data {
                        resolved = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let url = item as? URL {
                        resolved = url
                    }
                    if let resolved {
                        lock.lock()
                        found.append(resolved)
                        lock.unlock()
                    }
                }
            }
            group.notify(queue: .main) {
                guard !found.isEmpty else { return }
                FileTrayService.shared.addFiles(urls: found)
            }
            return true
        }

        // Non-colliding top-level Audio Output Route Picker Modal
        if audioService.isRoutePickerExpanded && windowManager.currentTab == .media {
            // Soft dimming veil & tap-catcher covering entire expanded notch
            Color.black.opacity(0.4)
                .frame(
                    width: windowManager.expandedSize.width,
                    height: windowManager.expandedSize.height
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        audioService.isRoutePickerExpanded = false
                    }
                }
                .transition(.opacity)
                .zIndex(500)

            // Dedicated floating output selection card (100% solid, zero collision with lyrics or scrubber)
            AudioRoutePickerCard(audioService: audioService)
                .padding(.top, topNotchClearance + 30)
                .padding(.trailing, 16)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)),
                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing))
                ))
                .zIndex(501)
        }
    }
    .frame(
        width: windowManager.expandedSize.width,
        height: windowManager.expandedSize.height,
        alignment: .top
    )
}
}

// MARK: - Dedicated Top-Level Audio Route Picker Card

/// Floating modal card for switching active CoreAudio output routes.
/// Styled with 100% solid dark backdrop and high z-index to guarantee zero visual collisions.
public struct AudioRoutePickerCard: View {
    @ObservedObject var audioService: AudioPeripheralsService
    @State private var hoveredRouteId: String? = nil

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("AUDIO OUTPUT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.8)
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.top, 7)
            .padding(.bottom, 2)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 6)
                .padding(.bottom, 2)

            ForEach(audioService.selectableRoutes) { route in
                Button(action: {
                    audioService.selectRoute(route)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        audioService.isRoutePickerExpanded = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: route.iconName)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(route.isActive ? .white : .white.opacity(0.65))
                            .frame(width: 16)

                        Text(route.name)
                            .font(.system(size: 11, weight: route.isActive ? .semibold : .regular))
                            .foregroundColor(route.isActive ? .white : .white.opacity(0.85))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 6)

                        if route.isActive {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(hoveredRouteId == route.id ? Color.white.opacity(0.09) : (route.isActive ? Color.white.opacity(0.04) : Color.clear))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        hoveredRouteId = route.id
                    } else if hoveredRouteId == route.id {
                        hoveredRouteId = nil
                    }
                }
            }
        }
        .padding(4)
        .frame(width: 216)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(red: 22/255, green: 22/255, blue: 26/255))
                .shadow(color: Color.black.opacity(0.7), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
        )
    }
}
