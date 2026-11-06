import AppKit

public struct ScreenGeometry {
    public static var currentScreen: NSScreen? {
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    public static var hasPhysicalNotch: Bool {
        guard let screen = currentScreen else { return false }
        return screen.safeAreaInsets.top > 0 && screen.auxiliaryTopLeftArea != nil
    }

    /// Apple Silicon MacBook Pro native hardware notch bottom corner radius (~11.5 pt).
    public static let nativeNotchBottomRadius: CGFloat = 11.5

    /// Apple Silicon MacBook Pro native hardware notch top ear fillet radius (~10.5 pt).
    public static let nativeNotchTopEarRadius: CGFloat = 10.5

    /// Width of the physical MacBook notch's vertical black body (excluding the top ear fillets).
    public static var physicalNotchBodyWidth: CGFloat {
        let fullWidth = notchSize.width
        if hasPhysicalNotch {
            return max(140, fullWidth - (nativeNotchTopEarRadius * 2.0))
        }
        return fullWidth
    }

    public static var notchSize: CGSize {
        guard let screen = currentScreen else {
            return CGSize(width: 200, height: 34)
        }

        let safeTop = screen.safeAreaInsets.top
        if safeTop > 0,
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            let notchWidth = screen.frame.width - (leftArea.width + rightArea.width)
            if notchWidth > 60 && notchWidth < 400 {
                return CGSize(width: ceil(notchWidth), height: ceil(safeTop))
            }
        }

        // Default floating pill size for external displays or non-notch Macs
        return CGSize(width: 200, height: 34)
    }

    public static func notchFrame(for size: CGSize) -> NSRect {
        guard let screen = currentScreen else {
            return NSRect(x: 100, y: 100, width: size.width, height: size.height)
        }

        let screenFrame = screen.frame
        let originX = screenFrame.midX - (size.width / 2.0)
        let originY = screenFrame.maxY - size.height

        return NSRect(x: originX, y: originY, width: size.width, height: size.height)
    }

    /// Strict physical body interaction zone for the compact notch.
    /// Strictly matches the visible physical notch body and expanded wings so the notch only activates
    /// when the pointer physically enters the notch body itself, not when nearby.
    public static func compactHoverFrame(for size: CGSize) -> NSRect {
        guard let screen = currentScreen else { return .zero }
        let screenFrame = screen.frame
        let baseFrame = notchFrame(for: size)

        let hoverWidth = baseFrame.width
        let hoverX = screenFrame.midX - (hoverWidth / 2.0)
        let hoverBottom = baseFrame.minY
        let hoverTop = screenFrame.maxY
        let hoverHeight = hoverTop - hoverBottom

        return NSRect(x: hoverX, y: hoverBottom, width: hoverWidth, height: hoverHeight)
    }

    /// Hover containment zone for the expanded dashboard.
    /// Provides generous padding around the expanded container to prevent premature collapse
    /// during rapid trackpad gestures and cursor navigation.
    public static func expandedHoverFrame(for size: CGSize) -> NSRect {
        guard let screen = currentScreen else { return .zero }
        let screenFrame = screen.frame
        let baseFrame = notchFrame(for: size)

        let hoverWidth = baseFrame.width + 64.0
        let hoverX = screenFrame.midX - (hoverWidth / 2.0)
        let hoverBottom = baseFrame.minY - 36.0
        let hoverTop = screenFrame.maxY + 10.0
        let hoverHeight = hoverTop - hoverBottom

        return NSRect(x: hoverX, y: hoverBottom, width: hoverWidth, height: hoverHeight)
    }

    private static var lastMissionControlCheck: (time: Date, result: Bool) = (.distantPast, false)

    /// Determines whether macOS Mission Control (Spaces selection overview) is currently active on screen.
    public static func isMissionControlActive() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastMissionControlCheck.time) < 0.15 {
            return lastMissionControlCheck.result
        }

        let options: CGWindowListOption = [.optionOnScreenOnly]
        guard let windowInfosRef = CGWindowListCopyWindowInfo(options, kCGNullWindowID),
              let windowList = windowInfosRef as NSArray? else {
            lastMissionControlCheck = (now, false)
            return false
        }

        let screenFrame = currentScreen?.frame ?? .zero

        for entry in windowList {
            guard let dict = entry as? [String: Any],
                  let ownerName = dict[kCGWindowOwnerName as String] as? String,
                  ownerName == "Dock",
                  let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary else {
                continue
            }

            let layer = dict[kCGWindowLayer as String] as? Int ?? 0
            let bounds = CGRect(dictionaryRepresentation: boundsDict) ?? .zero
            // Mission Control is a Dock-owned window at layer 20 that covers the ENTIRE display.
            // However, macOS ALSO keeps an identical full-screen Dock window at layer 20 whenever the plain
            // desktop / Finder is active, so geometry alone cannot distinguish the two. During real Mission
            // Control the Dock process is the frontmost application, which is the discriminating signal.
            let coversDisplay = bounds.width >= screenFrame.width - 2 && bounds.height >= screenFrame.height - 2
            let dockIsFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.dock"
            if layer == 20 && coversDisplay && dockIsFrontmost {
                lastMissionControlCheck = (now, true)
                return true
            }
        }
        lastMissionControlCheck = (now, false)
        return false
    }
}

