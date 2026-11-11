import AppKit
import SwiftUI

/// System-wide notification names emitted by `NotchWindow` upon trackpad gesture recognition.
public extension Notification.Name {
    static let obeliskSwipeNext = Notification.Name("obeliskSwipeNext")
    static let obeliskSwipePrev = Notification.Name("obeliskSwipePrev")
}

/// Custom borderless, non-activating `NSPanel` anchored to the top screen bezel.
/// Intercepts two-finger trackpad scroll events and three-finger swipe gestures before SwiftUI
/// hosting views consume them, enabling seamless page transitions.
public final class NotchWindow: NSPanel {
    private var lastSwipeTime: Date = .distantPast
    private var swipeAccumulatedX: CGFloat = 0
    private var hasTriggeredInCurrentGesture: Bool = false

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = NSWindow.Level(NSWindow.Level.statusBar.rawValue + 1)
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        // WindowServer animates frame changes of ordinary panels (notably inside Mission Control), which
        // plays a second shrink/grow animation on top of the SwiftUI morph. All morphing is SwiftUI-driven.
        self.animationBehavior = .none

        self.registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.item"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }

    override public var canBecomeKey: Bool {
        if WindowManager.shared.isExpanded { return true }
        if case .scheduledAlert = HardwareTelemetryService.shared.activeTransientHUD { return true }
        return false
    }

    override public var canBecomeMain: Bool {
        if WindowManager.shared.isExpanded { return true }
        if case .scheduledAlert = HardwareTelemetryService.shared.activeTransientHUD { return true }
        return false
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            let key = event.charactersIgnoringModifiers?.lowercased()
            switch key {
            case "c":
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
            case "v":
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
            case "x":
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
            case "a":
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) { return true }
            case "z":
                let isRedo = event.modifierFlags.contains(.shift)
                let sel = isRedo ? Selector(("redo:")) : Selector(("undo:"))
                if NSApp.sendAction(sel, to: nil, from: self) { return true }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override public func sendEvent(_ event: NSEvent) {
        if ScreenGeometry.isMissionControlActive() {
            // Keep notch completely static during Mission Control by swallowing all interaction events
            switch event.type {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                 .mouseMoved, .leftMouseDragged, .rightMouseDragged,
                 .mouseEntered, .mouseExited, .scrollWheel, .otherMouseDown, .otherMouseUp:
                return
            default:
                break
            }
        }
        if event.type == .leftMouseDown && WindowManager.shared.isExpanded {
            if !self.isKeyWindow {
                NSApp.activate(ignoringOtherApps: true)
                self.makeKeyAndOrderFront(nil)
            }
        }
        if event.type == .scrollWheel {
            if handleScrollEvent(event) {
                return
            }
        }
        super.sendEvent(event)
    }

    private func handleScrollEvent(_ event: NSEvent) -> Bool {
        if event.phase == .began {
            swipeAccumulatedX = 0
            hasTriggeredInCurrentGesture = false
        }

        if event.phase == .ended || event.phase == .cancelled {
            swipeAccumulatedX = 0
            hasTriggeredInCurrentGesture = false
            return false
        }

        if !event.momentumPhase.isEmpty && event.momentumPhase != [] {
            return false
        }

        let dx = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : (event.deltaX * 10)
        let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : (event.deltaY * 10)

        let settings = ObeliskSettings.shared

        if abs(dx) > abs(dy) && abs(dx) > 0.6 {
            guard settings.enableHorizontalSwipe && WindowManager.shared.isExpanded else { return false }
            guard !hasTriggeredInCurrentGesture else { return true }

            let now = Date()
            guard now.timeIntervalSince(lastSwipeTime) > 0.28 else { return true }

            swipeAccumulatedX += dx

            let threshold: CGFloat = 22.0
            let invert = settings.invertHorizontalSwipe
            if swipeAccumulatedX < -threshold {
                hasTriggeredInCurrentGesture = true
                lastSwipeTime = now
                swipeAccumulatedX = 0
                triggerNavigation(forward: invert ? true : false)
            } else if swipeAccumulatedX > threshold {
                hasTriggeredInCurrentGesture = true
                lastSwipeTime = now
                swipeAccumulatedX = 0
                triggerNavigation(forward: invert ? false : true)
            }
            return true
        }
        return false
    }

    override public func swipe(with event: NSEvent) {
        guard !ScreenGeometry.isMissionControlActive() else { return }

        let now = Date()
        guard now.timeIntervalSince(lastSwipeTime) > 0.35 else {
            super.swipe(with: event)
            return
        }

        let settings = ObeliskSettings.shared
        let invert = settings.invertHorizontalSwipe

        if event.deltaX < -0.2 && settings.enableHorizontalSwipe {
            lastSwipeTime = now
            triggerNavigation(forward: invert ? true : false)
        } else if event.deltaX > 0.2 && settings.enableHorizontalSwipe {
            lastSwipeTime = now
            triggerNavigation(forward: invert ? false : true)
        } else {
            super.swipe(with: event)
        }
    }

    private func triggerNavigation(forward: Bool) {
        Task { @MainActor in
            guard !ScreenGeometry.isMissionControlActive() else { return }
            guard WindowManager.shared.isExpanded else { return }
            WindowManager.shared.navigateTab(forward: forward)
            NotificationCenter.default.post(
                name: forward ? .obeliskSwipeNext : .obeliskSwipePrev,
                object: nil
            )
        }
    }
}

/// Custom NSHostingView that handles mouse clicks to expand the notch,
/// acts as a native NSDraggingDestination to intercept dragged files and auto-expand into File Tray,
/// while delegating pointer hover tracking to WindowManager's unified screen cursor monitor.
public final class NotchHostingView<Content: View>: NSHostingView<Content> {
    @MainActor @preconcurrency required public init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.item"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.item"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }

    // MARK: - Drag Destination Support (Auto-open File Tray)

    public override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        guard WindowManager.hasFileDragOnPasteboard(pboard) else { return [] }

        Task { @MainActor in
            let wm = WindowManager.shared
            if !wm.isExpanded {
                wm.expand(openingTab: .file)
            } else if wm.currentTab != .file {
                wm.switchToTab(.file, updateLastActiveTab: false)
            }
        }
        return .copy
    }

    public override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        guard WindowManager.hasFileDragOnPasteboard(pboard) else { return [] }

        Task { @MainActor in
            let wm = WindowManager.shared
            if !wm.isExpanded {
                wm.expand(openingTab: .file)
            } else if wm.currentTab != .file {
                wm.switchToTab(.file, updateLastActiveTab: false)
            }
        }
        return .copy
    }

    public override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            Task { @MainActor in
                FileTrayService.shared.addFiles(urls: urls)
            }
            return true
        }
        return false
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        let wm = WindowManager.shared
        let visibleSize = wm.isExpanded ? wm.expandedSize : wm.currentCompactSize
        let notchRect = NSRect(
            x: bounds.midX - (visibleSize.width / 2.0),
            y: bounds.maxY - visibleSize.height,
            width: visibleSize.width,
            height: visibleSize.height
        )
        if notchRect.contains(point) {
            return super.hitTest(point)
        }
        return nil
    }

    public override func resetCursorRects() {
        let wm = WindowManager.shared
        let visibleSize = wm.isExpanded ? wm.expandedSize : wm.currentCompactSize
        let notchRect = NSRect(
            x: bounds.midX - (visibleSize.width / 2.0),
            y: bounds.maxY - visibleSize.height,
            width: visibleSize.width,
            height: visibleSize.height
        )
        if !wm.isExpanded {
            addCursorRect(notchRect, cursor: .pointingHand)
        } else {
            super.resetCursorRects()
        }
    }

    public override func mouseDown(with event: NSEvent) {
        guard !ScreenGeometry.isMissionControlActive() else { return }
        if NotificationService.shared.activeNotification != nil {
            NotificationService.shared.dismissNotification()
            return
        }
        if case .scheduledAlert = HardwareTelemetryService.shared.activeTransientHUD {
            let loc = event.locationInWindow
            let wm = WindowManager.shared
            let visibleSize = wm.isExpanded ? wm.expandedSize : wm.currentCompactSize
            let notchRect = NSRect(
                x: bounds.midX - (visibleSize.width / 2.0),
                y: bounds.maxY - visibleSize.height,
                width: visibleSize.width,
                height: visibleSize.height
            )
            // If the user clicks the right wing area (where the [ OK ] button lives)
            let rightWingMinX = bounds.midX + (ScreenGeometry.notchSize.width / 2.0) - 8.0
            if loc.x >= rightWingMinX && notchRect.contains(loc) {
                ScheduledAlertService.shared.dismissActiveAlert()
                return
            }
            // If clicked on the left wing / notch body during alert, expand to alert tab
            if notchRect.contains(loc) && ObeliskSettings.shared.triggerMode != .hoverOnly {
                WindowManager.shared.expand(openingTab: .alert)
                return
            }
            super.mouseDown(with: event)
            return
        }
        if !WindowManager.shared.isExpanded && ObeliskSettings.shared.triggerMode != .hoverOnly {
            WindowManager.shared.expand()
            return
        }
        super.mouseDown(with: event)
    }
}
