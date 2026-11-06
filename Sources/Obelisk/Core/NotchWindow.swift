import AppKit
import SwiftUI

/// System-wide notification names emitted by `NotchWindow` upon trackpad gesture recognition.
public extension Notification.Name {
    static let obeliskSwipeNext = Notification.Name("obeliskSwipeNext")
    static let obeliskSwipePrev = Notification.Name("obeliskSwipePrev")
    static let obeliskSwipeDown = Notification.Name("obeliskSwipeDown")
    static let obeliskSwipeUp = Notification.Name("obeliskSwipeUp")
}

/// Custom borderless, non-activating `NSPanel` anchored to the top screen bezel.
/// Intercepts two-finger trackpad scroll events and three-finger swipe gestures before SwiftUI
/// hosting views consume them, enabling seamless page and detail transitions.
public final class NotchWindow: NSPanel {
    private var lastSwipeTime: Date = .distantPast
    private var swipeAccumulatedX: CGFloat = 0
    private var swipeAccumulatedY: CGFloat = 0
    private var hasTriggeredInCurrentGesture: Bool = false

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
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
        return false
    }

    override public var canBecomeMain: Bool {
        return false
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
        if event.type == .scrollWheel {
            handleScrollEvent(event)
        }
        super.sendEvent(event)
    }

    private func handleScrollEvent(_ event: NSEvent) {
        if event.phase == .began {
            swipeAccumulatedX = 0
            swipeAccumulatedY = 0
            hasTriggeredInCurrentGesture = false
        }

        if event.phase == .ended || event.phase == .cancelled {
            swipeAccumulatedX = 0
            swipeAccumulatedY = 0
            hasTriggeredInCurrentGesture = false
            return
        }

        if !event.momentumPhase.isEmpty && event.momentumPhase != [] {
            return
        }

        guard !hasTriggeredInCurrentGesture else { return }

        let now = Date()
        guard now.timeIntervalSince(lastSwipeTime) > 0.35 else { return }

        let dx = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : (event.deltaX * 10)
        let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : (event.deltaY * 10)

        let settings = ObeliskSettings.shared

        if abs(dx) > abs(dy) && abs(dx) > 0.8 {
            guard settings.enableHorizontalSwipe else { return }
            swipeAccumulatedX += dx

            let threshold: CGFloat = 16.0
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
        } else if abs(dy) > abs(dx) && abs(dy) > 0.8 {
            guard settings.enableVerticalSwipe else { return }
            swipeAccumulatedY += dy

            let thresholdY: CGFloat = 16.0
            if swipeAccumulatedY < -thresholdY {
                hasTriggeredInCurrentGesture = true
                lastSwipeTime = now
                swipeAccumulatedY = 0
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .obeliskSwipeDown, object: nil)
                }
            } else if swipeAccumulatedY > thresholdY {
                hasTriggeredInCurrentGesture = true
                lastSwipeTime = now
                swipeAccumulatedY = 0
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .obeliskSwipeUp, object: nil)
                }
            }
        }
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
        } else if event.deltaY < -0.2 && settings.enableVerticalSwipe {
            lastSwipeTime = now
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .obeliskSwipeDown, object: nil)
            }
        } else if event.deltaY > 0.2 && settings.enableVerticalSwipe {
            lastSwipeTime = now
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .obeliskSwipeUp, object: nil)
            }
        } else {
            super.swipe(with: event)
        }
    }

    private func triggerNavigation(forward: Bool) {
        DispatchQueue.main.async {
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
        let hasFiles = pboard.types?.contains(where: {
            $0 == .fileURL ||
            $0.rawValue.contains("file-url") ||
            $0.rawValue.contains("NSFilenamesPboardType") ||
            $0.rawValue.contains("public.item")
        }) == true

        guard hasFiles else { return [] }

        Task { @MainActor in
            let wm = WindowManager.shared
            if !wm.isExpanded {
                wm.expand(openingTab: .file)
            } else if wm.currentTab != .file {
                wm.switchToTab(.file)
            }
        }
        return .copy
    }

    public override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        let hasFiles = pboard.types?.contains(where: {
            $0 == .fileURL ||
            $0.rawValue.contains("file-url") ||
            $0.rawValue.contains("NSFilenamesPboardType") ||
            $0.rawValue.contains("public.item")
        }) == true
        return hasFiles ? .copy : []
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
        guard wm.isExpanded else { return nil }
        let visibleSize = wm.expandedSize
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
        Task { @MainActor in
            guard !ScreenGeometry.isMissionControlActive() else { return }
            if !WindowManager.shared.isExpanded && ObeliskSettings.shared.triggerMode != .hoverOnly {
                WindowManager.shared.expand()
                return
            }
        }
        super.mouseDown(with: event)
    }
}
