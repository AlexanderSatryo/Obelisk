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

        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            self.activeNotification = notification
            if !WindowManager.shared.isExpanded {
                WindowManager.shared.updateCompactWidth(animated: false)
            }
        }

        // Schedule auto-dismiss for unhandled standby HUD
        let timeout = max(5.0, ObeliskSettings.shared.notificationAutoDismissSeconds)
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
                activeNotification = updated
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
