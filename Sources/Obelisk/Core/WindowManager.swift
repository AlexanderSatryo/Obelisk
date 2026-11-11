import AppKit
import SwiftUI
import Combine

/// Identifies the top-level interactive pages inside the expanded Obelisk dashboard.
public enum ObeliskTab: Int, CaseIterable {
    case media = 0
    case weather = 1
    case calendar = 2
    case file = 3
    case notification = 4

    public var icon: String {
        switch self {
        case .media: return "play.circle.fill"
        case .weather: return "cloud.sun.fill"
        case .calendar: return "calendar"
        case .file: return "tray.and.arrow.down.fill"
        case .notification: return "bell.fill"
        }
    }

    public var title: String {
        switch self {
        case .media: return "Media"
        case .weather: return "Weather"
        case .calendar: return "Calendar"
        case .file: return "File"
        case .notification: return "Notifications"
        }
    }
}

/// Manages the lifecycle, sizing, hover geometry, and tab navigation of the floating Obelisk Notch panel.
/// Uses a fixed transparent `expandedCanvasSize` during expansion so SwiftUI handles 100% of the
/// morphing animation on the GPU without triggering WindowServer resize jitter.
@MainActor
public final class WindowManager: ObservableObject {
    public static let shared = WindowManager()

    @Published public var isExpanded: Bool = false
    @Published public var isHovered: Bool = false
    /// 0 while the notch is hidden during a Space-switch slide, animated back to 1 when the new Space has settled.
    @Published public var presence: CGFloat = 1
    @Published public var currentTab: ObeliskTab = .media
    @Published public var compactWidth: CGFloat = ScreenGeometry.notchSize.width
    @Published public var compactHeight: CGFloat = ScreenGeometry.notchSize.height
    @Published public var expandedSize: CGSize = CGSize(width: 480, height: 225)

    /// Fixed transparent canvas size when expanded so AppKit `NSWindow` never resizes mid-animation.
    private let expandedCanvasSize = CGSize(width: 900, height: 600)

    private var window: NotchWindow?
    private var hoverStartTime: Date?
    private var collapseWindowWorkItem: DispatchWorkItem?
    private var cursorMonitorTimer: Timer?
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var appActivityToken: NSObjectProtocol?
    private var outsideTickCount: Int = 0
    private var lastExpandTime: Date = .distantPast
    private var lastCollapseTime: Date = .distantPast
    private var isCollapsing: Bool = false

    private init() {
        self.compactWidth = ScreenGeometry.notchSize.width
        self.compactHeight = ScreenGeometry.notchSize.height
        let settings = ObeliskSettings.shared
        switch settings.defaultOpeningTab {
        case .lastUsed:
            if settings.enabledTabs.contains(settings.lastActiveTab) {
                self.currentTab = settings.lastActiveTab
            }
        case .alwaysMedia:
            if settings.enabledTabs.contains(.media) { self.currentTab = .media }
        case .alwaysWeather:
            if settings.enabledTabs.contains(.weather) { self.currentTab = .weather }
        case .alwaysCalendar:
            if settings.enabledTabs.contains(.calendar) { self.currentTab = .calendar }
        case .alwaysFile:
            if settings.enabledTabs.contains(.file) { self.currentTab = .file }
        case .alwaysNotification:
            if settings.enabledTabs.contains(.notification) { self.currentTab = .notification }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleActiveSpaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    public var currentCompactSize: CGSize {
        CGSize(width: compactWidth, height: compactHeight)
    }

    public var activeCompactTopEarRadius: CGFloat {
        let baseWidth = ScreenGeometry.notchSize.width
        if compactWidth > baseWidth + 4 {
            let extra = compactWidth - baseWidth
            return min(CGFloat(ObeliskSettings.shared.compactTopCornerRadius), extra * 0.25)
        }
        return 0.0
    }

    /// Initializes and orders front the non-activating top-bezel `NotchWindow`.
    public func setupWindow() {
        self.compactWidth = ScreenGeometry.notchSize.width
        self.compactHeight = ScreenGeometry.notchSize.height

        // The window keeps ONE constant, transparent canvas frame for its entire lifetime. Resizing an
        // NSWindow is animated by WindowServer inside Mission Control, which replays a second shrink/grow
        // animation on top of the SwiftUI morph. While compact the window is completely click-through,
        // so Finder, desktop, and other apps receive 100% of all clicks and drags without obstruction.
        let initialFrame = ScreenGeometry.notchFrame(for: expandedCanvasSize)
        let panel = NotchWindow(contentRect: initialFrame)
        panel.ignoresMouseEvents = true
        let rootView = RootView(windowManager: self)
        let hostingView = NotchHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: initialFrame.size)
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.window = panel
        updateCompactWidth(animated: false)
        startUnifiedCursorMonitor()
    }

    /// Dynamically computes the balanced wing width based on the download filename, speed and status,
    /// guaranteeing that both left and right wings open with the EXACT same symmetrical width.
    public func computeDownloadWingWidth(fileName: String, statusText: String?, progress: Double?) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let shortName = DownloadMonitorService.shortenDownloadDisplayName(fileName)
        let nameWidth = ceil((shortName as NSString).size(withAttributes: [.font: font]).width)

        // Left wing content width: icon (13pt) + spacing (5.5pt) + speed/status (approx 44-52pt)
        let leftContentWidth: CGFloat = 13 + 5.5 + 50 // ~68.5 pt

        // Right wing content width:
        let rightContentWidth: CGFloat
        if let st = statusText, (st == "Download Complete" || st == "Download Failed") {
            let stWidth = ceil((st as NSString).size(withAttributes: [.font: font]).width)
            rightContentWidth = stWidth
        } else if let frac = progress {
            let txt = "\(Int(round(frac * 100)))%"
            let txtWidth = ceil((txt as NSString).size(withAttributes: [.font: font]).width)
            // shortName + spacing (6.5pt) + circular ring (15pt) + spacing (5.5pt) + percent text
            rightContentWidth = nameWidth + 6.5 + 15 + 5.5 + txtWidth
        } else {
            // shortName + spacing (6.5pt) + circular ring (15pt) + spacing (5.5pt) + size text
            rightContentWidth = nameWidth + 6.5 + 15 + 5.5 + 46
        }

        // Symmetrical margin on both sides of content:
        let sideMargin: CGFloat = 12
        let needed = max(leftContentWidth, rightContentWidth) + (sideMargin * 2)

        // Balanced symmetrical width: min 112 pt, max 138 pt so both wings are clean, equal and never collide
        return min(max(needed, 112), 138)
    }

    /// Dynamically computes the balanced wing width for battery transient HUD notifications (including Unplug Charger / Fully Charged),
    /// guaranteeing that both left and right content elements are precisely and symmetrically centered
    /// between the physical MacBook Pro bezel (185 pt) and the outer notch ear curve.
    public func computeBatteryWingWidth(statusText: String, percentage: Int, isCharging: Bool) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let boldFont = NSFont.systemFont(ofSize: 11, weight: .bold)
        let medFont = NSFont.systemFont(ofSize: 10.5, weight: .medium)

        let leftContentWidth: CGFloat
        if statusText.contains("Fully Charged") {
            let textW = ceil(("Fully Charged" as NSString).size(withAttributes: [.font: font]).width)
            leftContentWidth = 13 + 6 + textW
        } else if statusText == "Disconnected" || statusText == "Unplugged" {
            let textW = ceil(("Disconnected" as NSString).size(withAttributes: [.font: font]).width)
            leftContentWidth = 14 + 6 + textW
        } else {
            let title = isCharging ? "Charging" : (percentage <= 20 ? "Low Battery" : "Battery")
            let textW = ceil((title as NSString).size(withAttributes: [.font: font]).width)
            leftContentWidth = 24 + 7 + textW
        }

        let rightContentWidth: CGFloat
        if statusText.contains("Fully Charged") {
            let pctW = ceil(("100%" as NSString).size(withAttributes: [.font: boldFont]).width)
            let subW = ceil(("Unplug Charger" as NSString).size(withAttributes: [.font: medFont]).width)
            rightContentWidth = pctW + 5 + 5 + 5 + subW
        } else if statusText == "Disconnected" || statusText == "Unplugged" {
            let pctStr = "\(percentage)%"
            let pctW = ceil((pctStr as NSString).size(withAttributes: [.font: boldFont]).width)
            let subW = ceil(("On Battery" as NSString).size(withAttributes: [.font: medFont]).width)
            rightContentWidth = pctW + 4 + 5 + 4 + subW
        } else {
            let pctStr = "\(percentage)%"
            let pctW = ceil((pctStr as NSString).size(withAttributes: [.font: boldFont]).width)
            let cleanSub = NotchTransientHUDBar.extractBatterySubtitle(statusText, pct: percentage, isCharging: isCharging)
            let subW = cleanSub.isEmpty ? 0 : ceil((cleanSub as NSString).size(withAttributes: [.font: medFont]).width) + 13
            rightContentWidth = pctW + subW
        }

        // Symmetrical margin on both sides of content:
        // Guarantees that content sits comfortably centered between outer ear and physical MacBook Pro bezel
        let sideMargin: CGFloat = 26
        let leftWingNeeded = leftContentWidth + (sideMargin * 2)
        let rightWingNeeded = rightContentWidth + (sideMargin * 2)

        let desiredWing = max(leftWingNeeded, rightWingNeeded)
        return min(max(desiredWing, 140), 280)
    }

    /// Recomputes the compact notch width and height based on transient connection HUDs, active media, and user preferences.
    public func updateCompactWidth(animated: Bool = true) {
        let baseWidth = ScreenGeometry.notchSize.width
        let baseHeight = ScreenGeometry.notchSize.height
        let settings = ObeliskSettings.shared
        let track = MediaManager.shared.currentTrack
        let hasTrack = !track.title.isEmpty && track.title != "No Media Playing"

        let targetWidth: CGFloat
        let targetHeight: CGFloat
        let customBaseHeight = max(24, baseHeight + CGFloat(settings.compactHeightOffset))
        if let hud = HardwareTelemetryService.shared.activeTransientHUD {
            let isBatteryHUD: Bool
            let isVolOrBright: Bool
            let isCapsLockHUD: Bool
            let isDownloadHUD: Bool
            switch hud {
            case .battery:
                isBatteryHUD = true
                isVolOrBright = false
                isCapsLockHUD = false
                isDownloadHUD = false
            case .volume, .brightness:
                isBatteryHUD = false
                isVolOrBright = true
                isCapsLockHUD = false
                isDownloadHUD = false
            case .capsLock:
                isBatteryHUD = false
                isVolOrBright = false
                isCapsLockHUD = true
                isDownloadHUD = false
            case .download:
                isBatteryHUD = false
                isVolOrBright = false
                isCapsLockHUD = false
                isDownloadHUD = true
            default:
                isBatteryHUD = false
                isVolOrBright = false
                isCapsLockHUD = false
                isDownloadHUD = false
            }

            switch settings.standbyHUDStyle {
            case .downwardCard:
                // Extends downward below the camera housing, like the AirPods connection card on iPhone.
                targetWidth = max(380, baseWidth + 190)
                targetHeight = customBaseHeight + NotchTransientHUDBar.extendedCardHeight
            case .horizontalWings:
                // Symmetrical, sleek wings matching dynamic content or configured presets
                let extraWidth: CGFloat
                if isDownloadHUD, case .download(let fileName, let statusText, _, let progress) = hud {
                    let wingW = computeDownloadWingWidth(fileName: fileName, statusText: statusText, progress: progress)
                    extraWidth = max(CGFloat(settings.compactWidthOffset), wingW * 2)
                } else if isBatteryHUD, case .battery(let pct, let isCharging, let statusText) = hud {
                    let wingW = computeBatteryWingWidth(statusText: statusText, percentage: pct, isCharging: isCharging)
                    extraWidth = max(CGFloat(settings.compactWidthOffset), wingW * 2)
                } else {
                    let hudExtra: CGFloat = isVolOrBright ? 290 : (isCapsLockHUD ? 240 : 250)
                    extraWidth = max(CGFloat(settings.compactWidthOffset), hudExtra)
                }
                targetWidth = baseWidth + extraWidth
                targetHeight = customBaseHeight
            }
        } else if let notif = NotificationService.shared.activeNotification {
            let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            let nameWidth = ceil((notif.appName as NSString).size(withAttributes: [.font: font]).width)
            let leftContentWidth = 16 + 6 + nameWidth
            let rightContentWidth: CGFloat = 118 // "New Notifications!"
            let sideMargin: CGFloat = 18
            let leftWingNeeded = leftContentWidth + (sideMargin * 2)
            let rightWingNeeded = rightContentWidth + (sideMargin * 2)
            let desiredWing = max(leftWingNeeded, rightWingNeeded)
            let wingW = min(max(desiredWing, 130), 152)
            targetWidth = baseWidth + (wingW * 2)
            targetHeight = customBaseHeight
        } else {
            let leftAlways = (settings.leftWingContent == .weatherMini || settings.leftWingContent == .batteryStatus || settings.leftWingContent == .cpuLoad)
            let rightAlways = (settings.rightWingStyle == .batteryOrPrivacy || settings.rightWingStyle == .systemTelemetry)
            let bothHidden = (settings.leftWingContent == .hidden && settings.rightWingStyle == .hidden)

            let hasDownload = settings.showDownloadsOnStandby && DownloadMonitorService.shared.isDownloading

            let shouldWiden: Bool
            switch settings.compactWingMode {
            case .alwaysMinimal:
                shouldWiden = hasDownload
            case .alwaysWide:
                shouldWiden = !bothHidden
            case .dynamicAuto:
                shouldWiden = hasDownload || (!bothHidden && (hasTrack || leftAlways || rightAlways))
            }
            if hasDownload, let first = DownloadMonitorService.shared.activeDownloads.first {
                let wingW = computeDownloadWingWidth(fileName: first.displayName, statusText: nil, progress: first.progressFraction)
                targetWidth = baseWidth + (wingW * 2)
            } else {
                targetWidth = shouldWiden ? (baseWidth + CGFloat(settings.compactWidthOffset)) : baseWidth
            }
            targetHeight = customBaseHeight
        }

        guard self.compactWidth != targetWidth || self.compactHeight != targetHeight else { return }

        if animated {
            let resp = settings.animationSpeed.expandResponse
            withAnimation(.spring(response: resp, dampingFraction: 0.82)) {
                self.compactWidth = targetWidth
                self.compactHeight = targetHeight
            }
        } else {
            self.compactWidth = targetWidth
            self.compactHeight = targetHeight
        }
    }

    /// Updates the expanded dashboard dimensions using the active width setting and requested height.
    public func setExpandedHeight(_ height: CGFloat) {
        // The flared top ears extend the silhouette outward, so the visible body keeps the configured width.
        let settings = ObeliskSettings.shared
        let targetWidth = CGFloat(settings.expandedWidth) + 2 * CGFloat(settings.expandedTopCornerRadius)
        let newSize = CGSize(width: targetWidth, height: height)
        guard self.expandedSize != newSize else { return }
        if isExpanded {
            let resp = settings.animationSpeed.expandResponse
            withAnimation(.spring(response: resp, dampingFraction: 0.82)) {
                self.expandedSize = newSize
            }
        } else {
            self.expandedSize = newSize
        }
    }

    // MARK: - Zero-Lag GPU Morphing Expand & Collapse

    /// Expands the notch into the full interactive dashboard.
    public func expand(openingTab: ObeliskTab? = nil) {
        // When opening explicitly for file dragging, don't let transient Mission Control check block it
        let isFileDrop = (openingTab == .file)
        if !isFileDrop {
            guard !ScreenGeometry.isMissionControlActive() else {
                hoverStartTime = nil
                self.isHovered = false
                return
            }
        }

        hoverStartTime = nil
        collapseWindowWorkItem?.cancel()
        collapseWindowWorkItem = nil
        self.isCollapsing = false

        guard !isExpanded, let window = self.window else { return }

        let settings = ObeliskSettings.shared
        if let tab = openingTab {
            if tab == .file && !settings.enableFileTab {
                settings.enableFileTab = true
            }
            self.currentTab = tab
            // When opening explicitly for file drop (openingTab == .file),
            // do NOT overwrite the user's remembered lastActiveTab!
            // settings.lastActiveTab preserves the user's manual preference (e.g. .media).
            if tab != .file {
                settings.lastActiveTab = tab
            }
        } else {
            applyDefaultOpeningTabIfNeeded(settings: settings)
        }
        ensureValidCurrentTab()

        lastExpandTime = Date()
        outsideTickCount = 0
        updateHeightForCurrentTab()

        window.ignoresMouseEvents = false
        window.orderFrontRegardless()

        let resp = settings.animationSpeed.expandResponse
        withAnimation(.spring(response: resp, dampingFraction: 0.84, blendDuration: 0)) {
            self.isExpanded = true
        }
    }

    /// Collapses the expanded dashboard back into the compact notch state and stops any active camera mirror.
    public func collapse() {
        hoverStartTime = nil

        guard isExpanded, self.window != nil else { return }

        if CameraMirrorService.shared.isMirrorActive {
            CameraMirrorService.shared.stopMirror()
        }

        self.isCollapsing = true
        self.isHovered = false
        lastCollapseTime = Date()
        outsideTickCount = 0
        CalendarService.shared.isCalendarExpanded = false
        BiometricPrivacyService.shared.lock()
        NSCursor.arrow.set()

        // If Mission Control is active, immediately collapse without animation delay to keep notch completely static
        if ScreenGeometry.isMissionControlActive(), let win = self.window {
            self.isExpanded = false
            self.isCollapsing = false
            win.ignoresMouseEvents = true
            return
        }

        let resp = ObeliskSettings.shared.animationSpeed.collapseResponse
        withAnimation(.spring(response: resp, dampingFraction: 0.88, blendDuration: 0)) {
            self.isExpanded = false
        }

        collapseWindowWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isExpanded, let win = self.window else { return }
            win.ignoresMouseEvents = true
            self.isCollapsing = false
            self.collapseWindowWorkItem = nil
            self.lastCollapseTime = Date()
            NSCursor.arrow.set()
        }
        collapseWindowWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + resp + 0.05, execute: work)
    }

    /// Toggles between the compact and expanded notch states.
    public func toggleExpand() {
        guard !ScreenGeometry.isMissionControlActive() else {
            hoverStartTime = nil
            self.isHovered = false
            if isExpanded { collapse() }
            return
        }
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    // MARK: - Mathematical Screen-Coordinate Hover & Cursor Tracking

    /// Starts a continuous, ultra-low-overhead (0.00% CPU) global screen cursor monitor.
    /// Operates consistently across normal windowed desktop, fullscreen apps, and all macOS Spaces
    /// without requiring Accessibility permissions.
    public func startUnifiedCursorMonitor() {
        cursorMonitorTimer?.invalidate()

        // Prevent App Nap from throttling the monitor while Obelisk is a background accessory app.
        if appActivityToken == nil {
            appActivityToken = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .latencyCritical],
                reason: "Obelisk notch hover tracking"
            )
        }

        // Global pointer-move events (no Accessibility permission required) wake the check immediately,
        // independent of timer scheduling, on desktop, in windowed apps, and in fullscreen.
        if globalMouseMonitor == nil {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.isExpanded {
                        self.checkExpandedCursorPosition()
                    } else {
                        self.checkCompactCursorPosition()
                    }
                }
            }
        }

        // The compact window is click-through, so clicks on the notch are detected globally instead.
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.isExpanded, !self.isCollapsing else { return }
                    guard ObeliskSettings.shared.triggerMode != .hoverOnly else { return }
                    let notchRect = ScreenGeometry.notchFrame(for: self.currentCompactSize)
                    if notchRect.contains(NSEvent.mouseLocation) {
                        self.expand()
                    }
                }
            }
        }

        let timer = Timer(timeInterval: 0.035, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                if self.isExpanded {
                    self.checkExpandedCursorPosition()
                } else {
                    self.checkCompactCursorPosition()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.cursorMonitorTimer = timer
    }

    /// Stops the global screen cursor monitor and removes event hooks.
    public func stopUnifiedCursorMonitor() {
        cursorMonitorTimer?.invalidate()
        cursorMonitorTimer = nil
        if let m = globalMouseMonitor {
            NSEvent.removeMonitor(m)
            globalMouseMonitor = nil
        }
        if let c = globalClickMonitor {
            NSEvent.removeMonitor(c)
            globalClickMonitor = nil
        }
        if let token = appActivityToken {
            ProcessInfo.processInfo.endActivity(token)
            appActivityToken = nil
        }
    }

    private static var lastConsumedDragChangeCount: Int = NSPasteboard(name: .drag).changeCount

    public static func syncDragPasteboardChangeCount() {
        lastConsumedDragChangeCount = NSPasteboard(name: .drag).changeCount
    }

    /// Determines whether the user is actively dragging one or more files/folders in macOS
    /// (e.g. from Finder, Desktop, or fullscreen app).
    public static var isSystemDraggingFiles: Bool {
        let isMouseDown = (NSEvent.pressedMouseButtons & 1) != 0
        guard isMouseDown else {
            syncDragPasteboardChangeCount()
            return false
        }

        let pboard = NSPasteboard(name: .drag)
        let currentCount = pboard.changeCount

        // Only consider it a file drag if a new drag was initiated (changeCount incremented)
        guard currentCount != lastConsumedDragChangeCount else {
            return false
        }

        // Verify that real file/folder URLs exist on the drag pasteboard
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: [
            NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty else {
            return false
        }

        return true
    }

    /// Evaluates whether the global pointer is within the compact notch interaction threshold.
    private func checkCompactCursorPosition() {
        guard !isExpanded, !isCollapsing, collapseWindowWorkItem == nil else {
            hoverStartTime = nil
            return
        }

        let mouseLoc = NSEvent.mouseLocation
        let isMouseDown = (NSEvent.pressedMouseButtons & 1) != 0

        // Synchronize drag pasteboard changeCount whenever mouse is NOT held down,
        // ensuring stale pasteboards from prior drags never trigger a false positive.
        if !isMouseDown {
            Self.syncDragPasteboardChangeCount()
        }

        // 1. Proactive File Drag Approach Detection
        // When the user drags a file/folder towards the notch bezel, immediately expand into the File Tray tab
        // with ZERO dwell latency and activate mouse events on the window.
        if isMouseDown && Self.isSystemDraggingFiles, let screen = ScreenGeometry.currentScreen {
            let screenFrame = screen.frame
            let approachWidth = max(expandedSize.width * 0.75, 360.0)
            let approachZone = NSRect(
                x: screenFrame.midX - (approachWidth / 2.0),
                y: screenFrame.maxY - 75.0,
                width: approachWidth,
                height: 75.0
            )
            if approachZone.contains(mouseLoc) {
                Self.syncDragPasteboardChangeCount()
                hoverStartTime = nil
                self.window?.ignoresMouseEvents = false
                self.expand(openingTab: .file)
                return
            }
        }

        guard ObeliskSettings.shared.triggerMode != .clickOnly else {
            hoverStartTime = nil
            return
        }
        guard !ScreenGeometry.isMissionControlActive() else {
            hoverStartTime = nil
            if isHovered { isHovered = false }
            return
        }

        let triggerZone = ScreenGeometry.compactHoverFrame(for: self.currentCompactSize)

        if triggerZone.contains(mouseLoc) {
            // Guard against instant re-expansion immediately after collapse
            if Date().timeIntervalSince(lastCollapseTime) < 0.35 {
                hoverStartTime = nil
                return
            }

            if !self.isHovered {
                self.isHovered = true
                NSCursor.pointingHand.set()
            }

            if hoverStartTime == nil {
                hoverStartTime = Date()
            }

            let requiredDwell = max(0.02, ObeliskSettings.shared.hoverDwellMs / 1000.0)
            if let start = hoverStartTime, Date().timeIntervalSince(start) >= requiredDwell {
                hoverStartTime = nil
                self.expand()
            }
        } else {
            hoverStartTime = nil
            if self.isHovered {
                self.isHovered = false
                NSCursor.arrow.set()
            }
        }
    }

    /// Evaluates whether the pointer has exited the expanded notch container.
    private func checkExpandedCursorPosition() {
        guard isExpanded else { return }

        let mouseLoc = NSEvent.mouseLocation
        let isMouseDown = (NSEvent.pressedMouseButtons & 1) != 0

        // Instantly collapse if user enters Mission Control while expanded (never while dragging file/clicking)
        if !isMouseDown && ScreenGeometry.isMissionControlActive() {
            collapse()
            return
        }

        // Never collapse while user is holding mouse button down (dragging file, slider, clicking buttons, etc.)
        if isMouseDown {
            outsideTickCount = 0
            return
        }

        let expandedZone = ScreenGeometry.expandedHoverFrame(for: expandedSize)

        if expandedZone.contains(mouseLoc) {
            outsideTickCount = 0
        } else {
            // Give opening animation time to settle before measuring exit ticks
            if Date().timeIntervalSince(lastExpandTime) < 0.35 {
                outsideTickCount = 0
                return
            }
            outsideTickCount += 1
            let requiredTicks = max(1, Int(round((ObeliskSettings.shared.exitGraceMs / 1000.0) / 0.035)))
            if outsideTickCount >= requiredTicks {
                collapse()
            }
        }
    }

    /// Processes pointer hover state changes on the compact notch.
    public func handleHoverChanged(_ hovering: Bool) {
        guard !ScreenGeometry.isMissionControlActive() else {
            hoverStartTime = nil
            if isHovered {
                self.isHovered = false
                NSCursor.arrow.set()
            }
            return
        }

        if hovering {
            let triggerZone = ScreenGeometry.compactHoverFrame(for: self.currentCompactSize)
            if triggerZone.contains(NSEvent.mouseLocation) {
                self.isHovered = true
                NSCursor.pointingHand.set()
            }
        } else {
            let triggerZone = ScreenGeometry.compactHoverFrame(for: self.currentCompactSize)
            if !triggerZone.contains(NSEvent.mouseLocation) {
                self.isHovered = false
                hoverStartTime = nil
                NSCursor.arrow.set()
            }
        }
    }

    // MARK: - Tab Navigation

    /// Ensures `currentTab` is included in `ObeliskSettings.shared.enabledTabs`.
    public func ensureValidCurrentTab() {
        let enabled = ObeliskSettings.shared.enabledTabs
        if !enabled.contains(currentTab), let first = enabled.first {
            switchToTab(first)
        }
    }

    private func applyDefaultOpeningTabIfNeeded(settings: ObeliskSettings) {
        let enabled = settings.enabledTabs

        let candidate: ObeliskTab?
        switch settings.defaultOpeningTab {
        case .lastUsed:
            if enabled.contains(settings.lastActiveTab) {
                candidate = settings.lastActiveTab
            } else if enabled.contains(self.currentTab) {
                candidate = self.currentTab
            } else {
                candidate = enabled.first ?? .media
            }
        case .alwaysMedia:
            candidate = .media
        case .alwaysWeather:
            candidate = .weather
        case .alwaysCalendar:
            candidate = .calendar
        case .alwaysFile:
            candidate = .file
        case .alwaysNotification:
            candidate = .notification
        }
        if let tab = candidate, enabled.contains(tab) {
            self.currentTab = tab
            settings.lastActiveTab = tab
        }
    }

    /// Switches directly to the specified tab and updates the container height.
    public func switchToTab(_ tab: ObeliskTab, updateLastActiveTab: Bool = true) {
        let resp = ObeliskSettings.shared.animationSpeed.expandResponse
        withAnimation(.spring(response: resp, dampingFraction: 0.82)) {
            self.currentTab = tab
            if updateLastActiveTab {
                ObeliskSettings.shared.lastActiveTab = tab
            }
            self.updateHeightForCurrentTab()
        }
    }

    /// Cycles forward or backward through the user's enabled dashboard tabs.
    public func navigateTab(forward: Bool) {
        let enabled = ObeliskSettings.shared.enabledTabs
        guard enabled.count > 1 else { return }

        let currentIndex = enabled.firstIndex(of: currentTab) ?? 0
        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % enabled.count
        } else {
            nextIndex = (currentIndex - 1 + enabled.count) % enabled.count
        }
        let nextTab = enabled[nextIndex]

        let resp = ObeliskSettings.shared.animationSpeed.expandResponse
        withAnimation(.spring(response: resp, dampingFraction: 0.82)) {
            self.currentTab = nextTab
            ObeliskSettings.shared.lastActiveTab = nextTab
            self.updateHeightForCurrentTab()
        }
    }

    /// Calculates and applies the uniform widescreen expanded height across all tabs.
    /// The total is derived from the real layout stack (top clearance below the camera housing, header row,
    /// divider, page body, and bottom inset) so that nothing overflows and gets re-centered upward into the bezel.
    public func updateHeightForCurrentTab() {
        let settings = ObeliskSettings.shared
        let baseClearance: CGFloat = ScreenGeometry.hasPhysicalNotch ? (ScreenGeometry.notchSize.height + 14) : 16
        let topClearance = max(6, baseClearance + CGFloat(settings.topNotchClearanceOffset))
        let mirrorExtra: CGFloat = CameraMirrorService.shared.isMirrorActive ? 158 : 0

        let headerRow: CGFloat = 22
        let dividerBlock: CGFloat = 1 + 6 + 6
        let pageBody: CGFloat = max(100, 116 + CGFloat(settings.expandedHeightOffset))
        let bottomInset: CGFloat = 14

        let natural = topClearance + headerRow + dividerBlock + pageBody + bottomInset + mirrorExtra
        let finalHeight = max(140, natural)
        setExpandedHeight(finalHeight)
    }

    @objc private func handleScreenChange() {
        self.compactWidth = ScreenGeometry.notchSize.width
        self.compactHeight = ScreenGeometry.notchSize.height
        window?.setFrame(ScreenGeometry.notchFrame(for: expandedCanvasSize), display: false)
        updateCompactWidth(animated: false)
    }

    @objc private func handleActiveSpaceChanged() {
        hoverStartTime = nil
        self.isHovered = false
        self.lastCollapseTime = Date()
        if isExpanded {
            collapse()
        }
    }
}
