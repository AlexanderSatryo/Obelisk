import AppKit
import Foundation
import SwiftUI

/// Central coordinator for incoming application notifications, Dynamic Island HUD animations,
/// and biometrics-protected card expansion.
@MainActor
public final class NotificationService: ObservableObject {
    public static let shared = NotificationService()

    @Published public var activeNotification: ObeliskNotification? = nil
    @Published public var isCardExpanded: Bool = false
    @Published public var recentNotifications: [ObeliskNotification] = []

    private var autoDismissWorkItem: DispatchWorkItem?

    private init() {
        loadRecentNotifications()
        setupDistributedNotificationListener()
    }

    /// Sets up an inter-process distributed notification observer so external scripts,
    /// terminal CLI commands, or background sidecars can post notifications to Obelisk.
    public func setupDistributedNotificationListener() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.obelisk.notification.post"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self else { return }
            let userInfo = notif.userInfo ?? [:]
            let appName = userInfo["appName"] as? String ?? userInfo["app"] as? String ?? "Notification"
            let bundleID = userInfo["bundleID"] as? String ?? userInfo["bundleIdentifier"] as? String ?? ""
            let sender = userInfo["sender"] as? String ?? "Incoming Message"
            let message = userInfo["message"] as? String ?? ""

            let item = ObeliskNotification(
                appName: appName,
                bundleIdentifier: bundleID,
                sender: sender,
                message: message
            )
            Task { @MainActor in
                self.postNotification(item)
            }
        }
    }

    /// Posts an incoming notification to the notch Dynamic Island.
    public func postNotification(_ notification: ObeliskNotification) {
        guard ObeliskSettings.shared.enableNotifications else { return }

        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil

        // Lock biometrics for incoming private notifications
        BiometricPrivacyService.shared.lock()
        self.isCardExpanded = false

        // Archive into recent notifications history
        recentNotifications.removeAll { $0.id == notification.id }
        recentNotifications.insert(notification, at: 0)
        if recentNotifications.count > 30 {
            recentNotifications = Array(recentNotifications.prefix(30))
        }
        saveRecentNotifications()

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

    /// Dismisses the active notification and returns the notch to its normal collapsed state.
    public func dismissNotification() {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil

        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            self.isCardExpanded = false
            self.activeNotification = nil
            BiometricPrivacyService.shared.lock()
            if !WindowManager.shared.isExpanded {
                WindowManager.shared.updateCompactWidth(animated: false)
            }
        }
    }

    /// Handles user clicks on the notification notch pill.
    public func handleNotchTap() {
        guard let notification = activeNotification else { return }

        // Cancel previous timer when user actively interacts
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil

        let requireBiometrics = ObeliskSettings.shared.requireTouchIDForNotifications
        if !requireBiometrics || BiometricPrivacyService.shared.isUnlocked {
            // Already authenticated or biometrics not required: toggle card expansion
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                self.isCardExpanded.toggle()
                WindowManager.shared.updateCompactWidth(animated: false)
            }
            if isCardExpanded {
                scheduleAutoDismiss(seconds: 25.0)
            }
        } else {
            // Prompt native Apple Touch ID
            let reason = "Touch ID to view notification from \(notification.appName)"
            BiometricPrivacyService.shared.authenticate(reason: reason) { [weak self] success in
                guard let self = self, success else { return }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
                    self.isCardExpanded = true
                    WindowManager.shared.updateCompactWidth(animated: false)
                }
                self.scheduleAutoDismiss(seconds: 25.0)
            }
        }
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

    // MARK: - Testing & Simulation Helpers

    public enum SampleNotificationType {
        case whatsapp
        case mail
        case telegram
        case messages
    }

    public func simulateSample(type: SampleNotificationType) {
        let notif: ObeliskNotification
        switch type {
        case .whatsapp:
            notif = ObeliskNotification(
                appName: "WhatsApp",
                bundleIdentifier: "net.whatsapp.WhatsApp",
                sender: "Sarah Jenkins",
                message: "Hey! Are you still working on the Obelisk update? Let's catch up later."
            )
        case .mail:
            notif = ObeliskNotification(
                appName: "Mail",
                bundleIdentifier: "com.apple.mail",
                sender: "Alexander Satryo",
                message: "Build completed successfully on Feature/Notification with Touch ID biometrics."
            )
        case .telegram:
            notif = ObeliskNotification(
                appName: "Telegram",
                bundleIdentifier: "ru.keepcoder.Telegram",
                sender: "Design Core",
                message: "New Apple Dynamic Island notification spec is ready for review."
            )
        case .messages:
            notif = ObeliskNotification(
                appName: "Messages",
                bundleIdentifier: "com.apple.MobileSMS",
                sender: "Mom",
                message: "Dinner is ready! Don't forget to take a break."
            )
        }
        postNotification(notif)
    }
}
