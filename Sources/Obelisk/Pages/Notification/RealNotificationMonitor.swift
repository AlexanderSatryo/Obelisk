import AppKit
import ApplicationServices
import Foundation

/// Dual-Engine real-time macOS notification monitor:
/// 1. Engine A (`usernoted` / `NotificationCenter` Unified Log Streamer): Detects every incoming push/local
///    notification delivery (`Delivering <NotificationRecord app:"..."`) in real time with zero Accessibility requirement,
///    even when the target app (e.g. WhatsApp, Mail, Telegram) is in the foreground or banner alerts are suppressed.
/// 2. Engine B (`AXUIElement` Banner Inspector): Reads rich sender and message body text from native
///    `com.apple.notificationcenterui` banners using identifier-aware AX traversal (`title`, `subtitle`, `body`).
@MainActor
public final class RealNotificationMonitor: ObservableObject {
    public static let shared = RealNotificationMonitor()

    @Published public var isAccessibilityTrusted: Bool = AXIsProcessTrusted()

    private var monitorTimer: Timer?
    private var logProcess: Process?
    private var logPipe: Pipe?

    private var lastCapturedSignature: String = ""
    private var lastCapturedTime: Date = .distantPast

    private var recentDeliveredIdents: [String: Date] = [:]

    private struct PendingDelivery {
        let id: UUID
        let bundleID: String
        let appName: String
        let ident: String
        let timestamp: Date
        var postedToService: Bool
        var enrichedWithBannerText: Bool
    }

    private var latestDelivery: PendingDelivery?

    private init() {}

    /// Starts both the Accessibility banner poller and the real-time `usernoted` log stream monitor.
    public func startMonitoring() {
        isAccessibilityTrusted = AXIsProcessTrusted()

        if monitorTimer == nil {
            monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.pollNotificationCenterBanners()
                }
            }
        }

        startLogStreamMonitor()
    }

    /// Stops all active notification monitors.
    public func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil

        logPipe?.fileHandleForReading.readabilityHandler = nil
        if let proc = logProcess, proc.isRunning {
            proc.terminate()
        }
        logProcess = nil
        logPipe = nil
    }

    /// Prompts macOS to grant Accessibility permission to Obelisk so banner message bodies can be read.
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Engine 1: Real-Time `usernoted` Unified Log Streamer

    private func startLogStreamMonitor() {
        guard logProcess == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "stream",
            "--predicate",
            "process == \"usernoted\" AND eventMessage CONTAINS \"Delivering <NotificationRecord\"",
            "--style",
            "compact"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            let lines = output.components(separatedBy: .newlines)
            for line in lines where line.contains("Delivering <NotificationRecord") {
                Task { @MainActor in
                    self?.handleLogDeliveryLine(line)
                }
            }
        }

        do {
            try process.run()
            self.logProcess = process
            self.logPipe = pipe
        } catch {
            print("Failed to start usernoted log stream monitor:", error)
        }
    }

    private func handleLogDeliveryLine(_ line: String) {
        guard ObeliskSettings.shared.enableNotifications else { return }

        // Extract app:"<bundleID>" and ident:"<ident>"
        guard let bundleID = extractQuotedValue(after: "app:\"", in: line) else { return }
        let ident = extractQuotedValue(after: "ident:\"", in: line) ?? UUID().uuidString

        // Ignore Obelisk's own notifications
        guard bundleID.lowercased() != "com.alxstry.obelisk" else { return }

        let now = Date()
        // Clean up old idents (> 15s)
        recentDeliveredIdents = recentDeliveredIdents.filter { now.timeIntervalSince($0.value) < 15.0 }
        let dedupKey = "\(bundleID)|\(ident)"
        guard recentDeliveredIdents[dedupKey] == nil else { return }
        recentDeliveredIdents[dedupKey] = now

        let resolvedAppName = Self.resolveAppName(for: bundleID)
        let deliveryID = UUID()

        self.latestDelivery = PendingDelivery(
            id: deliveryID,
            bundleID: bundleID,
            appName: resolvedAppName,
            ident: ident,
            timestamp: now,
            postedToService: false,
            enrichedWithBannerText: false
        )

        // Poll AX banners rapidly as the banner animates onto screen
        for delay in [0.15, 0.32, 0.50, 0.80] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.pollNotificationCenterBanners()
            }
        }

        // Fallback: if AX banner did not yield text within 0.45s (e.g. app is frontmost, banner style is None,
        // or Accessibility is not yet trusted), post the notification immediately using the verified app identity.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self = self,
                  var pending = self.latestDelivery,
                  pending.id == deliveryID,
                  !pending.postedToService else { return }

            pending.postedToService = true
            self.latestDelivery = pending

            let notification = ObeliskNotification(
                id: pending.id,
                appName: pending.appName,
                bundleIdentifier: pending.bundleID,
                sender: pending.appName,
                message: "New notification received",
                timestamp: pending.timestamp
            )
            NotificationService.shared.postNotification(notification)
        }
    }

    private func extractQuotedValue(after prefix: String, in text: String) -> String? {
        guard let range = text.range(of: prefix) else { return nil }
        let substring = text[range.upperBound...]
        guard let endQuote = substring.firstIndex(of: "\"") else { return nil }
        let value = String(substring[..<endQuote]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// Resolves a human-readable application name from a bundle identifier.
    public static func resolveAppName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            if let bundle = Bundle(url: url) {
                if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !displayName.isEmpty {
                    return displayName
                }
                if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !bundleName.isEmpty {
                    return bundleName
                }
            }
            let fileName = url.deletingPathExtension().lastPathComponent
            if !fileName.isEmpty {
                return fileName
            }
        }

        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let locName = running.localizedName, !locName.isEmpty {
            return locName
        }

        // Fallback: last component of bundle ID capitalized
        let lastPart = bundleID.components(separatedBy: ".").last ?? "Notification"
        return lastPart
    }

    // MARK: - Engine 2: Smart `AXUIElement` Banner Inspector

    private func pollNotificationCenterBanners() {
        guard ObeliskSettings.shared.enableNotifications else { return }
        isAccessibilityTrusted = AXIsProcessTrusted()
        guard isAccessibilityTrusted else { return }

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
        var subroleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)

        let role = roleRef as? String ?? ""
        let subrole = subroleRef as? String ?? ""

        let isBannerSubrole = (subrole == "AXNotificationCenterBanner" || subrole == "AXNotificationCenterAlert")
        let isCandidateContainer = isBannerSubrole || role == "AXGroup" || role == "AXButton"

        if isCandidateContainer {
            var descRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
            let desc = descRef as? String ?? ""

            if isBannerSubrole || (!desc.isEmpty && desc.contains(",")) {
                let extracted = extractBannerFields(from: element)
                if !extracted.allTexts.isEmpty {
                    handleExtractedBanner(extracted: extracted, rawDescription: desc)
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

    private struct BannerFields {
        var title: String?
        var subtitle: String?
        var body: String?
        var allTexts: [String] = []
    }

    private func extractBannerFields(from element: AXUIElement) -> BannerFields {
        var fields = BannerFields()

        func traverse(_ node: AXUIElement) {
            var roleRef: CFTypeRef?
            var idRef: CFTypeRef?
            var valRef: CFTypeRef?
            AXUIElementCopyAttributeValue(node, kAXRoleAttribute as CFString, &roleRef)
            AXUIElementCopyAttributeValue(node, kAXIdentifierAttribute as CFString, &idRef)
            AXUIElementCopyAttributeValue(node, kAXValueAttribute as CFString, &valRef)

            let role = roleRef as? String ?? ""
            let identifier = (idRef as? String ?? "").lowercased()
            if role == "AXStaticText",
               let rawVal = valRef as? String {
                let text = rawVal.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    fields.allTexts.append(text)
                    if identifier == "title" && fields.title == nil {
                        fields.title = text
                    } else if identifier == "subtitle" && fields.subtitle == nil {
                        fields.subtitle = text
                    } else if identifier == "body" && fields.body == nil {
                        fields.body = text
                    }
                }
            }

            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(node, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for child in children {
                    traverse(child)
                }
            }
        }

        traverse(element)
        return fields
    }

    private func handleExtractedBanner(extracted: BannerFields, rawDescription: String) {
        // Parse header app name from the leading segment of `rawDescription` ("AppName, Title, Body")
        let descParts = rawDescription
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let descHeaderApp = descParts.first ?? ""

        var resolvedAppName: String
        var resolvedBundleID: String = ""
        var sender: String
        var message: String

        let now = Date()
        let hasRecentDelivery: Bool
        if let pending = latestDelivery, now.timeIntervalSince(pending.timestamp) < 4.0 {
            hasRecentDelivery = true
            resolvedBundleID = pending.bundleID
            resolvedAppName = pending.appName
        } else {
            hasRecentDelivery = false
            resolvedAppName = descHeaderApp
        }

        if let title = extracted.title, let body = extracted.body {
            if (descHeaderApp == "Script Editor" || resolvedBundleID == "com.apple.ScriptEditor2"),
               let subtitle = extracted.subtitle, !subtitle.isEmpty {
                // Support AppleScript test notifications: `display notification "body" with title "WhatsApp" subtitle "Sender"`
                resolvedAppName = title
                resolvedBundleID = ""
                sender = subtitle
                message = body
            } else {
                if resolvedAppName.isEmpty {
                    resolvedAppName = title
                }
                if let subtitle = extracted.subtitle, !subtitle.isEmpty {
                    sender = "\(title) • \(subtitle)"
                } else {
                    sender = title
                }
                message = body
            }
        } else if extracted.allTexts.count >= 3 {
            let t0 = extracted.allTexts[0]
            let t1 = extracted.allTexts[1]
            let t2 = extracted.allTexts[2]
            if descHeaderApp == "Script Editor" {
                resolvedAppName = t0
                resolvedBundleID = ""
                sender = t1
                message = t2
            } else {
                if resolvedAppName.isEmpty { resolvedAppName = t0 }
                sender = t0 == resolvedAppName ? t1 : "\(t0) • \(t1)"
                message = t2
            }
        } else if extracted.allTexts.count == 2 {
            // Very common for WhatsApp / Telegram / Mail: 2 static texts = [SenderName, MessageBody]
            // while the application name is in `descHeaderApp` or `latestDelivery`!
            if resolvedAppName.isEmpty {
                resolvedAppName = descHeaderApp.isEmpty ? extracted.allTexts[0] : descHeaderApp
            }
            sender = extracted.allTexts[0]
            message = extracted.allTexts[1]
        } else if let only = extracted.allTexts.first {
            if resolvedAppName.isEmpty {
                resolvedAppName = descHeaderApp.isEmpty ? only : descHeaderApp
            }
            sender = resolvedAppName
            message = only
        } else {
            return
        }

        guard resolvedAppName != "Obelisk" else { return }

        let signature = "\(resolvedAppName)|\(sender)|\(message)"
        guard signature != lastCapturedSignature || now.timeIntervalSince(lastCapturedTime) > 6.0 else {
            return
        }

        lastCapturedSignature = signature
        lastCapturedTime = now

        // If Engine 1 (`log stream`) already created or is holding a PendingDelivery for this notification:
        if hasRecentDelivery, var pending = latestDelivery {
            pending.enrichedWithBannerText = true
            if pending.postedToService {
                // Upgrade the already-posted fallback notification in-place with full sender & message!
                self.latestDelivery = pending
                NotificationService.shared.enrichNotification(
                    id: pending.id,
                    appName: resolvedAppName,
                    bundleIdentifier: resolvedBundleID,
                    sender: sender,
                    message: message
                )
                return
            } else {
                // Post immediately with full details and mark pending as posted so fallback timer won't duplicate
                pending.postedToService = true
                self.latestDelivery = pending
                let notification = ObeliskNotification(
                    id: pending.id,
                    appName: resolvedAppName,
                    bundleIdentifier: resolvedBundleID,
                    sender: sender,
                    message: message,
                    timestamp: now
                )
                NotificationService.shared.postNotification(notification)
                return
            }
        }

        let notification = ObeliskNotification(
            appName: resolvedAppName,
            bundleIdentifier: resolvedBundleID,
            sender: sender,
            message: message,
            timestamp: now
        )
        NotificationService.shared.postNotification(notification)
    }
}
