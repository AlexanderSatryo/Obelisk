import AppKit
import Foundation
import SwiftUI

/// Central coordinator for incoming application notifications, Dynamic Island HUD animations,
/// and biometrics-protected card expansion.
@MainActor
public final class NotificationService: ObservableObject {
    public static let shared = NotificationService()

    @Published public var activeNotification: ObeliskNotification? = nil
    @Published public var recentNotifications: [ObeliskNotification] = []

    private var autoDismissWorkItem: DispatchWorkItem?
    private let distributedHelper = DistributedNotificationHelper()

    private init() {
        loadRecentNotifications()
        setupDistributedNotificationListener()
        setupApplicationActivationListener()
    }

    /// Sets up an inter-process distributed notification observer so external scripts,
    /// terminal CLI commands, or background sidecars can post notifications to Obelisk.
    public func setupDistributedNotificationListener() {
        distributedHelper.onReceive = { [weak self] userInfo in
            Task { @MainActor in
                guard let self = self else { return }
                let appName = userInfo["appName"] as? String ?? userInfo["app"] as? String ?? "Notification"
                let bundleID = userInfo["bundleID"] as? String ?? userInfo["bundleIdentifier"] as? String ?? ""
                let sender = userInfo["sender"] as? String ?? "Incoming Message"
                let message = userInfo["message"] as? String ?? ""
                let groupName = userInfo["groupName"] as? String ?? userInfo["group"] as? String

                let item = ObeliskNotification(
                    appName: appName,
                    bundleIdentifier: bundleID,
                    sender: sender,
                    message: message,
                    groupName: groupName
                )
                self.postNotification(item)
            }
        }

        DistributedNotificationCenter.default().addObserver(
            distributedHelper,
            selector: #selector(DistributedNotificationHelper.handleNotification(_:)),
            name: NSNotification.Name("com.obelisk.notification.post"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    /// Posts an incoming notification to the notch Dynamic Island.
    public func postNotification(_ notification: ObeliskNotification) {
        guard ObeliskSettings.shared.enableNotifications else { return }

        // Always archive into recent notifications history
        recentNotifications.removeAll { $0.id == notification.id }
        recentNotifications.insert(notification, at: 0)
        if recentNotifications.count > 30 {
            recentNotifications = Array(recentNotifications.prefix(30))
        }
        saveRecentNotifications()

        // Check if incoming notification passes the selected category filter for the notch HUD
        let currentFilter = ObeliskSettings.shared.notificationFilterCategory
        guard notification.matches(filter: currentFilter) else { return }

        // Immediately dismiss any active transient volume/brightness HUD so the incoming notification
        // appears in the standby notch instantly without waiting for the volume notification to finish
        HardwareTelemetryService.shared.dismissTransientHUD(animated: false)

        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil

        // Lock biometrics for incoming private notifications only when the notch is collapsed
        if !WindowManager.shared.isExpanded {
            BiometricPrivacyService.shared.lock()
        }

        let isAlreadyShowing = (self.activeNotification != nil)

        withAnimation(.spring(response: isAlreadyShowing ? 0.26 : 0.34, dampingFraction: 0.80)) {
            self.activeNotification = notification
            WindowManager.shared.updateCompactWidth(animated: !WindowManager.shared.isExpanded)
        }

        // Snappy auto-dismiss: brief appearance (default 2.5s) so rapid / spam messages pop dynamically
        let timeout = min(max(1.5, ObeliskSettings.shared.notificationAutoDismissSeconds), 5.0)
        scheduleAutoDismiss(seconds: timeout)
    }

    /// Updates the sender, group, message, and avatar of an existing notification when rich banner text arrives shortly after push delivery.
    public func enrichNotification(id: UUID, appName: String? = nil, bundleIdentifier: String? = nil, sender: String, message: String, groupName: String? = nil, avatarImage: NSImage? = nil) {
        if let idx = recentNotifications.firstIndex(where: { $0.id == id }) {
            let old = recentNotifications[idx]
            let updated = ObeliskNotification(
                id: old.id,
                appName: appName ?? old.appName,
                bundleIdentifier: bundleIdentifier ?? old.bundleIdentifier,
                sender: sender,
                message: message,
                timestamp: old.timestamp,
                appIcon: old.appIcon,
                appURL: old.appURL,
                groupName: groupName ?? old.groupName,
                avatarImage: avatarImage ?? old.avatarImage
            )
            recentNotifications[idx] = updated
            if activeNotification?.id == id {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    activeNotification = updated
                    WindowManager.shared.updateCompactWidth(animated: !WindowManager.shared.isExpanded)
                }
            }
            saveRecentNotifications()
        }
    }

    /// Dismisses the active notification and returns the notch to its normal collapsed state.
    public func dismissNotification() {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil

        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            self.activeNotification = nil
            if !WindowManager.shared.isExpanded {
                BiometricPrivacyService.shared.lock()
                WindowManager.shared.updateCompactWidth(animated: false)
            }
        }
    }

    /// Handles user clicks on the notification notch pill: dismisses the standby alert cleanly.
    public func handleNotchTap() {
        dismissNotification()
    }

    /// Opens the application associated with the active notification and dismisses the notch card.
    public func openApp() {
        guard let notification = activeNotification else { return }
        openNotificationApp(notification)
        dismissNotification()
    }

    /// Opens the application for any notification item in the history feed.
    public func openNotificationApp(_ notification: ObeliskNotification) {
        if let appURL = notification.appURL ?? (notification.bundleIdentifier.isEmpty ? nil : NSWorkspace.shared.urlForApplication(withBundleIdentifier: notification.bundleIdentifier)) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
        } else if let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased() == notification.appName.lowercased()
        }) {
            running.activate(options: .activateIgnoringOtherApps)
        }
        removeRecentNotification(id: notification.id)
    }

    /// Automatically clears pending notifications when the user opens or switches to the target application,
    /// matching native macOS Notification Center and iOS behavior.
    private func setupApplicationActivationListener() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in
                self?.handleApplicationActivated(app)
            }
        }
    }

    /// Handles application focus switches: automatically dismisses pending HUD and clears notifications
    /// for the application the user just opened.
    public func handleApplicationActivated(_ app: NSRunningApplication) {
        let bundleID = app.bundleIdentifier?.lowercased() ?? ""
        let appName = app.localizedName?.lowercased() ?? ""

        guard !bundleID.isEmpty || !appName.isEmpty else { return }

        // 1. If the active standby notch HUD notification belongs to this application, dismiss it immediately
        if let active = activeNotification, notification(active, matchesAppBundleID: bundleID, appName: appName) {
            dismissNotification()
        }

        // 2. In notification history feed: remove notifications for this application
        let toRemove = recentNotifications.filter { notification($0, matchesAppBundleID: bundleID, appName: appName) }
        guard !toRemove.isEmpty else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            recentNotifications.removeAll { notification($0, matchesAppBundleID: bundleID, appName: appName) }
            saveRecentNotifications()
        }
    }

    private func notification(_ notif: ObeliskNotification, matchesAppBundleID bundleID: String, appName: String) -> Bool {
        let notifBundle = notif.bundleIdentifier.lowercased()
        let notifApp = notif.appName.lowercased()

        // 1. Direct bundle identifier match
        if !bundleID.isEmpty && notifBundle == bundleID {
            return true
        }

        // 2. Direct localized app name match
        if !appName.isEmpty && notifApp == appName {
            return true
        }

        // 3. WhatsApp variants (e.g. net.whatsapp.WhatsApp or Catalyst wrapper)
        if (bundleID.contains("whatsapp") || appName.contains("whatsapp")) &&
           (notifBundle.contains("whatsapp") || notifApp.contains("whatsapp")) {
            return true
        }

        // 4. Telegram variants
        if (bundleID.contains("telegram") || appName.contains("telegram")) &&
           (notifBundle.contains("telegram") || notifApp.contains("telegram")) {
            return true
        }

        // 5. Slack variants
        if (bundleID.contains("slack") || appName.contains("slack")) &&
           (notifBundle.contains("slack") || notifApp.contains("slack")) {
            return true
        }

        // 6. Discord variants
        if (bundleID.contains("discord") || appName.contains("discord")) &&
           (notifBundle.contains("discord") || notifApp.contains("discord")) {
            return true
        }

        return false
    }

    /// Removes a specific notification from recent history.
    public func removeRecentNotification(id: UUID) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            recentNotifications.removeAll { $0.id == id }
            saveRecentNotifications()
        }
    }

    /// Clears all recent notifications from history.
    public func clearAllRecentNotifications() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            recentNotifications.removeAll()
            saveRecentNotifications()
        }
    }

    private func loadRecentNotifications() {
        guard let data = UserDefaults.standard.data(forKey: "cfg_recentNotifications") else { return }
        do {
            let decoded = try JSONDecoder().decode([ObeliskNotification].self, from: data)
            self.recentNotifications = decoded
        } catch {
            print("Failed to decode recent notifications:", error)
        }
    }

    private func saveRecentNotifications() {
        do {
            let data = try JSONEncoder().encode(recentNotifications)
            UserDefaults.standard.set(data, forKey: "cfg_recentNotifications")
        } catch {
            print("Failed to encode recent notifications:", error)
        }
    }

    private func scheduleAutoDismiss(seconds: TimeInterval) {
        autoDismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self, self.activeNotification != nil else { return }
                self.dismissNotification()
            }
        }
        autoDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

final class DistributedNotificationHelper: NSObject {
    var onReceive: (([AnyHashable: Any]) -> Void)?

    @objc func handleNotification(_ notif: Notification) {
        onReceive?(notif.userInfo ?? [:])
    }
}
