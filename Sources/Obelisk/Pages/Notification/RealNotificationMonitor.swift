import AppKit
import ApplicationServices
import Foundation

/// Tri-Engine real-time macOS notification monitor:
/// 1. Engine A (`usernoted` Unified Log Streamer): Detects every incoming push/local notification delivery
///    (`Delivering <NotificationRecord app:"..."`) in real time with zero latency, even when the target app
///    is in the foreground or banner alerts are suppressed.
/// 2. Engine B (`AXUIElement` Banner Inspector): Reads rich sender and message body text from native
///    `com.apple.notificationcenterui` banners using identifier-aware and description-aware AX traversal.
/// 3. Engine C (`AXUIElement` Direct App Inspector for WhatsApp Catalyst): Reads real-time sender and message
///    previews directly from WhatsApp's `ChatListView_TableView` when macOS suppresses the banner (`Presenting ... as none`).
@MainActor
public final class RealNotificationMonitor: ObservableObject {
    public static let shared = RealNotificationMonitor()

    @Published public var isAccessibilityTrusted: Bool = AXIsProcessTrusted()

    private var monitorTimer: Timer?
    private var logProcess: Process?
    private var logPipe: Pipe?
    private var tickCounter: Int = 0
    private var hasPromptedAccessibilityThisSession: Bool = false

    private var lastCapturedSignature: String = ""
    private var lastCapturedTime: Date = .distantPast

    private var recentDeliveredIdents: [String: Date] = [:]
    private var recentMatchedWhatsAppSignatures: [String: Date] = [:]

    private struct PendingDelivery {
        let id: UUID
        let bundleID: String
        let appName: String
        let ident: String
        let timestamp: Date
        var enrichedWithBannerText: Bool
    }

    private var pendingDeliveries: [PendingDelivery] = []
    private var baselineWhatsAppStates: [String: String] = [:]

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopMonitoring()
            }
        }
    }

    /// Starts the Accessibility banner poller, WhatsApp state tracker, and real-time `usernoted` log stream monitor.
    public func startMonitoring() {
        isAccessibilityTrusted = AXIsProcessTrusted()
        if !isAccessibilityTrusted && !hasPromptedAccessibilityThisSession {
            hasPromptedAccessibilityThisSession = true
            requestAccessibilityPermission(resetTCC: true)
        }

        // Capture initial WhatsApp baseline once and backfill any placeholder notifications
        if isAccessibilityTrusted {
            captureWhatsAppBaseline()
            backfillUnenrichedWhatsAppNotifications()
        }

        if monitorTimer == nil {
            monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.50, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.tickCounter += 1
                    let wasTrusted = self.isAccessibilityTrusted
                    self.isAccessibilityTrusted = AXIsProcessTrusted()

                    if !wasTrusted && self.isAccessibilityTrusted {
                        self.captureWhatsAppBaseline()
                        self.backfillUnenrichedWhatsAppNotifications()
                    }

                    guard self.isAccessibilityTrusted else { return }

                    self.pollNotificationCenterBanners()

                    // Every ~2.0s, if any placeholder notification exists, backfill it from WhatsApp
                    if self.tickCounter % 4 == 0 {
                        if NotificationService.shared.recentNotifications.contains(where: { $0.message == "New notification received" }) {
                            self.backfillUnenrichedWhatsAppNotifications()
                        }
                    }
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
    public func requestAccessibilityPermission(resetTCC: Bool = false) {
        if resetTCC && !AXIsProcessTrusted() {
            let resetProc = Process()
            resetProc.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            resetProc.arguments = ["reset", "Accessibility", "com.alxstry.obelisk"]
            try? resetProc.run()
            resetProc.waitUntilExit()
        }
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
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
        // Clean up old idents (> 15s) and old pending deliveries (> 12s)
        recentDeliveredIdents = recentDeliveredIdents.filter { now.timeIntervalSince($0.value) < 15.0 }
        pendingDeliveries = pendingDeliveries.filter { now.timeIntervalSince($0.timestamp) < 12.0 }

        let dedupKey = "\(bundleID)|\(ident)"
        guard recentDeliveredIdents[dedupKey] == nil else { return }
        recentDeliveredIdents[dedupKey] = now

        let resolvedAppName = ObeliskNotification.stripBidiControlMarks(Self.resolveAppName(for: bundleID))
        let deliveryID = UUID()

        // Post the notification to NotificationService IMMEDIATELY (0ms delay) so the standby notch wings
        // ([App Icon + App Name] | [New Notifications!]) expand in complete sync with the incoming alert sound.
        let initialNotification = ObeliskNotification(
            id: deliveryID,
            appName: resolvedAppName,
            bundleIdentifier: bundleID,
            sender: resolvedAppName,
            message: "New notification received",
            timestamp: now
        )
        NotificationService.shared.postNotification(initialNotification)

        let pending = PendingDelivery(
            id: deliveryID,
            bundleID: bundleID,
            appName: resolvedAppName,
            ident: ident,
            timestamp: now,
            enrichedWithBannerText: false
        )
        pendingDeliveries.append(pending)

        // If this notification is from WhatsApp, poll WhatsApp's live chat list & open message table across short intervals
        if bundleID == "net.whatsapp.WhatsApp" {
            for delay in [0.04, 0.16, 0.35, 0.65, 1.10, 1.75] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self = self else { return }
                    self.pollWhatsAppChatList(for: deliveryID)
                }
            }
        }

        // Poll AX banners across the banner presentation lifecycle (including AvatarViewSnapshotter delay)
        for delay in [0.12, 0.30, 0.55, 0.90, 1.40, 2.00] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.pollNotificationCenterBanners()
            }
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
                if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                    let clean = ObeliskNotification.stripBidiControlMarks(displayName)
                    if !clean.isEmpty { return clean }
                }
                if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                    let clean = ObeliskNotification.stripBidiControlMarks(bundleName)
                    if !clean.isEmpty { return clean }
                }
            }
            let fileName = ObeliskNotification.stripBidiControlMarks(url.deletingPathExtension().lastPathComponent)
            if !fileName.isEmpty {
                return fileName
            }
        }

        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let locName = running.localizedName {
            let clean = ObeliskNotification.stripBidiControlMarks(locName)
            if !clean.isEmpty { return clean }
        }

        let lastPart = bundleID.components(separatedBy: ".").last ?? "Notification"
        return ObeliskNotification.stripBidiControlMarks(lastPart)
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
            let extracted = extractBannerFields(from: window)
            if !extracted.allTexts.isEmpty {
                var descRef: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXDescriptionAttribute as CFString, &descRef)
                let desc = ObeliskNotification.stripBidiControlMarks(descRef as? String ?? "")
                if handleExtractedBanner(extracted: extracted, rawDescription: desc) {
                    continue
                }
            }
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

        let isBannerSubrole = (subrole == "AXNotificationCenterBanner" || subrole == "AXNotificationCenterAlert" || subrole == "AXSystemDialog")
        let isCandidateContainer = isBannerSubrole || role == "AXGroup" || role == "AXButton" || role == "AXWindow"

        if isCandidateContainer {
            var descRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
            let desc = ObeliskNotification.stripBidiControlMarks(descRef as? String ?? "")

            let extracted = extractBannerFields(from: element)
            if !extracted.allTexts.isEmpty || (!desc.isEmpty && desc.contains(",")) {
                if handleExtractedBanner(extracted: extracted, rawDescription: desc) {
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
            var descRef: CFTypeRef?
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(node, kAXRoleAttribute as CFString, &roleRef)
            AXUIElementCopyAttributeValue(node, kAXIdentifierAttribute as CFString, &idRef)
            AXUIElementCopyAttributeValue(node, kAXValueAttribute as CFString, &valRef)
            AXUIElementCopyAttributeValue(node, kAXDescriptionAttribute as CFString, &descRef)
            AXUIElementCopyAttributeValue(node, kAXTitleAttribute as CFString, &titleRef)

            let role = roleRef as? String ?? ""
            let identifier = (idRef as? String ?? "").lowercased()
            if role == "AXStaticText" {
                let rawCandidate = (valRef as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (descRef as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (titleRef as? String).flatMap { $0.isEmpty ? nil : $0 }

                if let rawVal = rawCandidate {
                    let text = ObeliskNotification.stripBidiControlMarks(rawVal)
                    if !text.isEmpty && !fields.allTexts.contains(text) {
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

    @discardableResult
    private func handleExtractedBanner(extracted: BannerFields, rawDescription: String) -> Bool {
        let descParts = rawDescription
            .components(separatedBy: ",")
            .map { ObeliskNotification.stripBidiControlMarks($0) }
            .filter { !$0.isEmpty }
        let descHeaderApp = descParts.first ?? ""

        var resolvedAppName: String
        var resolvedBundleID: String = ""
        var sender: String
        var message: String
        var groupName: String? = nil

        let now = Date()
        let pendingIdx = pendingDeliveries.lastIndex(where: {
            !$0.enrichedWithBannerText && now.timeIntervalSince($0.timestamp) < 6.0
        })
        if let idx = pendingIdx {
            resolvedBundleID = pendingDeliveries[idx].bundleID
            resolvedAppName = pendingDeliveries[idx].appName
        } else {
            resolvedAppName = descHeaderApp
        }

        if let title = extracted.title, let body = extracted.body {
            if (descHeaderApp == "Script Editor" || resolvedBundleID == "com.apple.ScriptEditor2"),
               let subtitle = extracted.subtitle, !subtitle.isEmpty {
                resolvedAppName = title
                resolvedBundleID = ""
                sender = subtitle
                message = body
            } else {
                if resolvedAppName.isEmpty {
                    resolvedAppName = title
                }
                if let subtitle = extracted.subtitle, !subtitle.isEmpty {
                    sender = title
                    groupName = subtitle
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
                if t0 == resolvedAppName {
                    sender = t1
                    message = t2
                } else {
                    sender = t0
                    groupName = t1
                    message = t2
                }
            }
        } else if extracted.allTexts.count == 2 {
            if resolvedAppName.isEmpty {
                resolvedAppName = descHeaderApp.isEmpty ? extracted.allTexts[0] : descHeaderApp
            }
            sender = extracted.allTexts[0]
            message = extracted.allTexts[1]
        } else if descParts.count >= 3 {
            // CommunicationNotifications banner where description holds "AppName, Sender, Message"
            if resolvedAppName.isEmpty {
                resolvedAppName = descParts[0]
            }
            sender = descParts[1]
            message = descParts.dropFirst(2).joined(separator: ", ")
        } else if let only = extracted.allTexts.first {
            if resolvedAppName.isEmpty {
                resolvedAppName = descHeaderApp.isEmpty ? only : descHeaderApp
            }
            sender = resolvedAppName
            message = only
        } else {
            return false
        }

        resolvedAppName = ObeliskNotification.stripBidiControlMarks(resolvedAppName)
        let parsed = ObeliskNotification.parseSenderAndGroup(
            appName: resolvedAppName,
            bundleIdentifier: resolvedBundleID,
            rawSender: sender,
            rawGroup: groupName,
            rawMessage: message
        )
        sender = parsed.sender
        groupName = parsed.group
        message = parsed.message

        guard resolvedAppName != "Obelisk", !message.isEmpty else { return false }

        if let idx = pendingIdx {
            let deliveryID = pendingDeliveries[idx].id
            pendingDeliveries[idx].enrichedWithBannerText = true
            lastCapturedSignature = "\(resolvedAppName)|\(sender)|\(message)"
            lastCapturedTime = now

            NotificationService.shared.enrichNotification(
                id: deliveryID,
                appName: resolvedAppName,
                bundleIdentifier: resolvedBundleID,
                sender: sender,
                message: message,
                groupName: groupName
            )
            return true
        }

        let signature = "\(resolvedAppName)|\(sender)|\(message)"
        guard signature != lastCapturedSignature || now.timeIntervalSince(lastCapturedTime) > 6.0 else {
            return false
        }

        lastCapturedSignature = signature
        lastCapturedTime = now

        let notification = ObeliskNotification(
            appName: resolvedAppName,
            bundleIdentifier: resolvedBundleID,
            sender: sender,
            message: message,
            timestamp: now,
            groupName: groupName
        )
        NotificationService.shared.postNotification(notification)
        return true
    }

    // MARK: - Engine 3: Direct WhatsApp Catalyst `ChatListView_TableView` & `ChatMessagesTableView` AX Inspector

    private struct ParsedWhatsAppRow {
        let chatTitle: String
        let sender: String
        let message: String
        let timeToken: String
        let isUnread: Bool
        let isPinned: Bool
        let isSentByMe: Bool
        let matchesCurrentMinute: Bool
        let rawState: String
        let groupName: String?
    }

    private func captureWhatsAppBaseline() {
        let rows = readWhatsAppChatRows(includeOpenChatBubbles: false)
        guard !rows.isEmpty else { return }
        var stateMap: [String: String] = [:]
        for row in rows {
            stateMap[row.chatTitle] = row.rawState
        }
        baselineWhatsAppStates = stateMap
    }

    private func pollWhatsAppChatList(for deliveryID: UUID) {
        guard let idx = pendingDeliveries.firstIndex(where: { $0.id == deliveryID }),
              !pendingDeliveries[idx].enrichedWithBannerText else { return }

        let allRows = readWhatsAppChatRows(includeOpenChatBubbles: true)
        let receivedRows = allRows.filter { !$0.isSentByMe && !$0.message.isEmpty }
        guard !receivedRows.isEmpty else { return }

        let now = Date()
        recentMatchedWhatsAppSignatures = recentMatchedWhatsAppSignatures.filter {
            now.timeIntervalSince($0.value) < 45.0
        }

        func sig(_ row: ParsedWhatsAppRow) -> String {
            "\(row.sender)|\(row.groupName ?? "")|\(row.message)|\(row.timeToken)"
        }

        func isUnused(_ row: ParsedWhatsAppRow) -> Bool {
            recentMatchedWhatsAppSignatures[sig(row)] == nil
        }

        var matchedRow: ParsedWhatsAppRow? = nil

        // 1. Unused received row whose state changed relative to baseline
        if !baselineWhatsAppStates.isEmpty {
            matchedRow = receivedRows.first(where: { row in
                isUnused(row) && baselineWhatsAppStates[row.chatTitle] != row.rawState
            })
        }

        // 2. Unused unread received row matching the current minute
        if matchedRow == nil {
            matchedRow = receivedRows.first(where: { isUnused($0) && $0.isUnread && $0.matchesCurrentMinute })
        }

        // 3. Unused received row (including open chat message bubbles) matching the current minute
        if matchedRow == nil {
            matchedRow = receivedRows.first(where: { isUnused($0) && $0.matchesCurrentMinute })
        }

        // 4. Unused unread received row
        if matchedRow == nil {
            matchedRow = receivedRows.first(where: { isUnused($0) && $0.isUnread && !$0.isPinned })
                ?? receivedRows.first(where: { isUnused($0) && $0.isUnread })
        }

        // 5. Any received row matching the current minute
        if matchedRow == nil {
            matchedRow = receivedRows.first(where: { $0.matchesCurrentMinute && $0.isUnread })
                ?? receivedRows.first(where: { $0.matchesCurrentMinute })
        }

        // 6. Top unread or unpinned received row
        if matchedRow == nil {
            matchedRow = receivedRows.first(where: { $0.isUnread && !$0.isPinned })
                ?? receivedRows.first(where: { $0.isUnread })
                ?? receivedRows.first(where: { !$0.isPinned })
        }

        guard let winner = matchedRow else { return }

        pendingDeliveries[idx].enrichedWithBannerText = true
        recentMatchedWhatsAppSignatures[sig(winner)] = now

        NotificationService.shared.enrichNotification(
            id: deliveryID,
            appName: "WhatsApp",
            bundleIdentifier: "net.whatsapp.WhatsApp",
            sender: winner.sender,
            message: winner.message,
            groupName: winner.groupName
        )

        captureWhatsAppBaseline()
    }

    /// Backfills any existing WhatsApp notifications in `recentNotifications` that still have `"New notification received"`.
    public func backfillUnenrichedWhatsAppNotifications() {
        let rows = readWhatsAppChatRows(includeOpenChatBubbles: true).filter { !$0.isSentByMe && !$0.message.isEmpty }
        guard !rows.isEmpty else { return }

        let unreadOrRecent = rows.filter { $0.isUnread } + rows.filter { !$0.isUnread && !$0.isPinned } + rows.filter { !$0.isUnread && $0.isPinned }
        guard !unreadOrRecent.isEmpty else { return }

        let service = NotificationService.shared
        let currentItems = service.recentNotifications
        var usedSignatures = Set<String>(
            currentItems
                .filter { $0.message != "New notification received" }
                .map { "\($0.sender)|\($0.groupName ?? "")|\($0.message)" }
        )

        for item in currentItems {
            if (item.bundleIdentifier == "net.whatsapp.WhatsApp" || item.appName == "WhatsApp"),
               item.message == "New notification received" {
                let itemTokens = Self.timeTokens(for: item.timestamp)
                let tokenMatch = rows.first(where: {
                    !($0.timeToken.isEmpty) && itemTokens.contains($0.timeToken) &&
                    !usedSignatures.contains("\($0.sender)|\($0.groupName ?? "")|\($0.message)")
                })
                let fallbackMatch = unreadOrRecent.first(where: {
                    !usedSignatures.contains("\($0.sender)|\($0.groupName ?? "")|\($0.message)")
                })

                if let matched = tokenMatch ?? fallbackMatch {
                    let sig = "\(matched.sender)|\(matched.groupName ?? "")|\(matched.message)"
                    usedSignatures.insert(sig)
                    service.enrichNotification(
                        id: item.id,
                        appName: "WhatsApp",
                        bundleIdentifier: "net.whatsapp.WhatsApp",
                        sender: matched.sender,
                        message: matched.message,
                        groupName: matched.groupName
                    )
                } else {
                    service.removeRecentNotification(id: item.id)
                }
            }
        }
    }

    private func resolveWhatsAppRootWindow(for axApp: AXUIElement) -> AXUIElement {
        var mainWinRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &mainWinRef) == .success,
           let mainWin = mainWinRef {
            return mainWin as! AXUIElement
        }
        var focusedWinRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWinRef) == .success,
           let focusedWin = focusedWinRef {
            return focusedWin as! AXUIElement
        }
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement],
           let firstWin = windows.first {
            return firstWin
        }
        return axApp
    }

    private func readWhatsAppChatRows(includeOpenChatBubbles: Bool = true) -> [ParsedWhatsAppRow] {
        guard AXIsProcessTrusted() else { return [] }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "net.whatsapp.WhatsApp")
        guard let app = apps.first else { return [] }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let rootWindow = resolveWhatsAppRootWindow(for: axApp)
        let currentTimeTokens = Self.timeTokens(for: Date())
        var parsedRows: [ParsedWhatsAppRow] = []

        // 1. Read open chat message bubbles from `ChatMessagesTableView` (newest first) so rapid messages
        //    in an active conversation are all captured even if the user immediately replies.
        if includeOpenChatBubbles,
           let msgTable = findAXElement(withIdentifier: "ChatMessagesTableView", in: rootWindow) {
            var tableDescRef: CFTypeRef?
            var cellsRef: CFTypeRef?
            AXUIElementCopyAttributeValue(msgTable, kAXDescriptionAttribute as CFString, &tableDescRef)
            AXUIElementCopyAttributeValue(msgTable, kAXChildrenAttribute as CFString, &cellsRef)

            let rawTableDesc = ObeliskNotification.stripBidiControlMarks(tableDescRef as? String ?? "")
            let prefix = "Messages in chat with "
            let openChatTitle = rawTableDesc.hasPrefix(prefix)
                ? ObeliskNotification.stripBidiControlMarks(String(rawTableDesc.dropFirst(prefix.count)))
                : ""

            if !openChatTitle.isEmpty, openChatTitle != "You",
               let cells = cellsRef as? [AXUIElement] {
                for cell in cells.suffix(10).reversed() {
                    var cellDescRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(cell, kAXDescriptionAttribute as CFString, &cellDescRef)
                    let rawCellDesc = cellDescRef as? String ?? ""
                    guard !rawCellDesc.isEmpty else { continue }
                    if let parsed = parseWhatsAppRow(desc: openChatTitle, val: rawCellDesc, currentTimeTokens: currentTimeTokens),
                       !parsed.isSentByMe {
                        parsedRows.append(parsed)
                    }
                }
            }
        }

        // 2. Read chat list rows from `ChatListView_TableView`
        if let table = findAXElement(withIdentifier: "ChatListView_TableView", in: rootWindow) {
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(table, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for row in children.prefix(15) {
                    var descRef: CFTypeRef?
                    var valRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(row, kAXDescriptionAttribute as CFString, &descRef)
                    AXUIElementCopyAttributeValue(row, kAXValueAttribute as CFString, &valRef)

                    let rawDesc = descRef as? String ?? ""
                    let rawVal = valRef as? String ?? ""
                    if let parsed = parseWhatsAppRow(desc: rawDesc, val: rawVal, currentTimeTokens: currentTimeTokens) {
                        parsedRows.append(parsed)
                    }
                }
            }
        }

        return parsedRows
    }

    private func findAXElement(withIdentifier targetID: String, in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        if depth > 14 { return nil }
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String, role == "AXMenuBar" {
            return nil
        }

        var idRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idRef) == .success,
           let id = idRef as? String, id == targetID {
            return element
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findAXElement(withIdentifier: targetID, in: child, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }

    private func parseWhatsAppRow(desc: String, val: String, currentTimeTokens: Set<String>) -> ParsedWhatsAppRow? {
        let d = ObeliskNotification.stripBidiControlMarks(desc)
        let v = ObeliskNotification.stripBidiControlMarks(val)
        guard !d.isEmpty, !v.isEmpty else { return nil }

        let isSentByMe = v.contains(", Sent to ") || v.hasPrefix("Your ")
        let isPinned = v.hasSuffix(", Pinned")
        let isGroupChat = v.range(of: #",\s*Received\s+in\s+"#, options: .regularExpression) != nil

        var isUnread = false
        var chatTitle = d
        if let unreadRange = d.range(of: #",\s*[\d\.,]+\s+unread\s+messages?$"#, options: .regularExpression) {
            chatTitle = String(d[..<unreadRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            isUnread = true
        }

        var body = v
        for suffix in [", Pinned", ", Muted", ". Mentioned.", ", Mentioned"] {
            if body.hasSuffix(suffix) {
                body = String(body.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let recRange = body.range(of: #",\s*(Received|Sent)\s+(from|in|to)\s+.*$"#, options: .regularExpression) {
            body = String(body[..<recRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var extractedTimeToken = ""
        var matchesCurrentMinute = false
        if let timeRange = body.range(of: #",\s*(\d{1,2}[\.:]\d{2}(\s*[APap][Mm])?|Yesterday|Kemarin|\d{1,2}\s+[A-Za-z]+.*)$"#, options: .regularExpression) {
            let matchedTimeSegment = String(body[timeRange])
                .replacingOccurrences(of: #"^,\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            extractedTimeToken = matchedTimeSegment
            if currentTimeTokens.contains(matchedTimeSegment) {
                matchesCurrentMinute = true
            }
            body = String(body[..<timeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var sender = chatTitle
        var groupName: String? = nil
        if body.lowercased().hasPrefix("message, ") {
            body = String(body.dropFirst("message, ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if body.hasPrefix("Message from ") {
            let rest = String(body.dropFirst("Message from ".count))
            if let commaIdx = rest.firstIndex(of: ",") {
                let groupSender = ObeliskNotification.stripBidiControlMarks(String(rest[..<commaIdx]))
                let msgPart = ObeliskNotification.stripBidiControlMarks(String(rest[rest.index(after: commaIdx)...]))
                if !groupSender.isEmpty {
                    sender = groupSender
                    groupName = chatTitle
                }
                body = msgPart
            }
        } else if isGroupChat, let fromRange = body.range(of: #"\s+from\s+([^,]+)$"#, options: .regularExpression) {
            let fullMatch = String(body[fromRange])
            let extractedSender = ObeliskNotification.stripBidiControlMarks(
                fullMatch.replacingOccurrences(of: #"^\s+from\s+"#, with: "", options: .regularExpression)
            )
            let msgPart = ObeliskNotification.stripBidiControlMarks(String(body[..<fromRange.lowerBound]))
            if !extractedSender.isEmpty && !msgPart.isEmpty {
                sender = extractedSender
                groupName = chatTitle
                body = msgPart
            }
        }

        return ParsedWhatsAppRow(
            chatTitle: chatTitle,
            sender: sender,
            message: body,
            timeToken: extractedTimeToken,
            isUnread: isUnread,
            isPinned: isPinned,
            isSentByMe: isSentByMe,
            matchesCurrentMinute: matchesCurrentMinute,
            rawState: "\(d)|\(v)",
            groupName: groupName
        )
    }

    private static func timeTokens(for date: Date) -> Set<String> {
        var tokens = Set<String>()
        let prev = date.addingTimeInterval(-60)
        let formats = ["HH.mm", "HH:mm", "H.mm", "H:mm", "h:mm a", "h.mm a"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            formatter.dateFormat = fmt
            tokens.insert(formatter.string(from: date))
            tokens.insert(formatter.string(from: prev))
        }
        return tokens
    }
}
