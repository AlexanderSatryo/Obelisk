import AppKit
import ApplicationServices
import Foundation

/// Monitors native macOS Notification Center banners via Accessibility (AXUIElement)
/// to detect real incoming notifications from applications (WhatsApp, Mail, Messages, Telegram, Slack, etc.).
@MainActor
public final class RealNotificationMonitor: ObservableObject {
    public static let shared = RealNotificationMonitor()

    private var monitorTimer: Timer?
    private var lastCapturedSignature: String = ""
    private var lastCapturedTime: Date = .distantPast

    private init() {}

    /// Starts observing macOS notification center banner windows.
    public func startMonitoring() {
        guard monitorTimer == nil else { return }

        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollNotificationCenterBanners()
            }
        }
    }

    /// Stops observing.
    public func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func pollNotificationCenterBanners() {
        guard ObeliskSettings.shared.enableNotifications else { return }

        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui")
        guard let app = apps.first else { return }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }

        for window in windows {
            scanElement(window)
        }
    }

    private func scanElement(_ element: AXUIElement) {
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        if role == "AXGroup" {
            var descRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
            let desc = descRef as? String ?? ""

            // macOS Notification banners have comma-separated descriptions like "AppName, Sender, Message"
            if !desc.isEmpty && desc.contains(",") {
                let texts = extractStaticTexts(from: element)
                if !texts.isEmpty {
                    handleExtractedNotification(texts: texts, rawDescription: desc)
                    return
                }
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                scanElement(child)
            }
        }
    }

    private func extractStaticTexts(from element: AXUIElement) -> [String] {
        var texts: [String] = []
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        var valRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valRef)

        let role = roleRef as? String ?? ""
        if role == "AXStaticText", let val = valRef as? String, !val.trimmingCharacters(in: .whitespaces).isEmpty {
            texts.append(val.trimmingCharacters(in: .whitespaces))
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                texts.append(contentsOf: extractStaticTexts(from: child))
            }
        }
        return texts
    }

    private func handleExtractedNotification(texts: [String], rawDescription: String) {
        let appName: String
        let sender: String
        let message: String

        if texts.count >= 3 {
            appName = texts[0]
            sender = texts[1]
            message = texts[2]
        } else if texts.count == 2 {
            appName = texts[0]
            sender = texts[0]
            message = texts[1]
        } else if texts.count == 1 {
            appName = texts[0]
            sender = texts[0]
            message = rawDescription
        } else {
            return
        }

        // Avoid capturing Obelisk internal alerts
        guard appName != "Obelisk" else { return }

        let signature = "\(appName)|\(sender)|\(message)"
        let now = Date()

        // Debounce duplicated detections (within 6 seconds)
        guard signature != lastCapturedSignature || now.timeIntervalSince(lastCapturedTime) > 6.0 else {
            return
        }

        lastCapturedSignature = signature
        lastCapturedTime = now

        let notification = ObeliskNotification(
            appName: appName,
            sender: sender,
            message: message,
            timestamp: now
        )

        NotificationService.shared.postNotification(notification)
    }
}
