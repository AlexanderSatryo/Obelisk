import AppKit
import Foundation

/// Represents an incoming rich notification displayed via the Dynamic Island notch HUD.
public struct ObeliskNotification: Identifiable, Equatable, Codable {
    public let id: UUID
    public let appName: String
    public let bundleIdentifier: String
    public let sender: String
    public let message: String
    public let timestamp: Date
    public let appIcon: NSImage?
    public let appURL: URL?
    public let groupName: String?
    public let avatarData: Data?

    public var avatarImage: NSImage? {
        if let d = avatarData {
            return NSImage(data: d)
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, appName, bundleIdentifier, sender, message, timestamp, groupName, avatarData
    }

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String = "",
        sender: String,
        message: String,
        timestamp: Date = Date(),
        appIcon: NSImage? = nil,
        appURL: URL? = nil,
        groupName: String? = nil,
        avatarImage: NSImage? = nil,
        avatarData: Data? = nil
    ) {
        let cleanAppName = ObeliskNotification.stripBidiControlMarks(appName)
        let parsed = ObeliskNotification.parseSenderAndGroup(
            appName: cleanAppName,
            bundleIdentifier: bundleIdentifier,
            rawSender: sender,
            rawGroup: groupName,
            rawMessage: message
        )

        self.id = id
        self.appName = cleanAppName
        self.bundleIdentifier = bundleIdentifier
        self.sender = parsed.sender
        self.groupName = parsed.group
        self.message = parsed.message
        self.timestamp = timestamp

        let effectiveAvatarData = avatarData ?? avatarImage?.tiffRepresentation
        self.avatarData = effectiveAvatarData

        let resolvedURL = appURL ?? ObeliskNotification.resolveAppURL(bundleIdentifier: bundleIdentifier, appName: cleanAppName)
        self.appURL = resolvedURL
        self.appIcon = appIcon ?? ObeliskNotification.resolveIcon(url: resolvedURL, bundleIdentifier: bundleIdentifier, appName: cleanAppName)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        let rawAppName = try container.decode(String.self, forKey: .appName)
        self.bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        let rawSender = try container.decode(String.self, forKey: .sender)
        let rawMessage = try container.decode(String.self, forKey: .message)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        let rawGroupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        self.avatarData = try container.decodeIfPresent(Data.self, forKey: .avatarData)

        let cleanAppName = ObeliskNotification.stripBidiControlMarks(rawAppName)
        let parsed = ObeliskNotification.parseSenderAndGroup(
            appName: cleanAppName,
            bundleIdentifier: bundleIdentifier,
            rawSender: rawSender,
            rawGroup: rawGroupName,
            rawMessage: rawMessage
        )

        self.appName = cleanAppName
        self.sender = parsed.sender
        self.groupName = parsed.group
        self.message = parsed.message

        let resolvedURL = ObeliskNotification.resolveAppURL(bundleIdentifier: bundleIdentifier, appName: cleanAppName)
        self.appURL = resolvedURL
        self.appIcon = ObeliskNotification.resolveIcon(url: resolvedURL, bundleIdentifier: bundleIdentifier, appName: cleanAppName)
    }

    /// Removes invisible Unicode directional marks (e.g. U+200E Left-to-Right Mark used by WhatsApp Catalyst).
    public static func stripBidiControlMarks(_ text: String) -> String {
        let bidiMarks: Set<Unicode.Scalar> = [
            "\u{200E}", "\u{200F}", "\u{202A}", "\u{202B}", "\u{202C}",
            "\u{202D}", "\u{202E}", "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}"
        ]
        let filtered = String(text.unicodeScalars.filter { !bidiMarks.contains($0) })
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Intelligently parses raw sender, group name, and message body across multiple notification schemas
    /// (e.g. "Sender (Group):", "Sender • Group", or "Sender: ChatMessage" from macOS Notification Center & WhatsApp).
    public static func parseSenderAndGroup(
        appName: String,
        bundleIdentifier: String,
        rawSender: String,
        rawGroup: String?,
        rawMessage: String
    ) -> (sender: String, group: String?, message: String) {
        var sender = rawSender.trimmingCharacters(in: .whitespacesAndNewlines)
        var group = rawGroup?.trimmingCharacters(in: .whitespacesAndNewlines)
        var message = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if group?.isEmpty == true { group = nil }

        // Clean invisible directional marks
        sender = stripBidiControlMarks(sender)
        group = group.map { stripBidiControlMarks($0) }
        message = stripBidiControlMarks(message)

        // Case 1: Subtitle joined with bullet " • " (e.g. "Alex • Group Name")
        if group == nil, let bulletRange = sender.range(of: " • ") {
            let part1 = String(sender[..<bulletRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let part2 = String(sender[bulletRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !part1.isEmpty && !part2.isEmpty {
                sender = part1
                group = part2
            }
        }

        // Case 2: Clean trailing colon and spaces from sender (e.g. "Alpin (DR.DAFAG):")
        while sender.hasSuffix(":") || sender.hasSuffix(" ") {
            sender = String(sender.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Case 3: Parenthesized group name with nested parentheses support
        // e.g. "Alpin Pasuruan (DR.DAFAG (Delegation, Reformation, Democration of Asean Federation and Association Group))"
        if group == nil, let firstParen = sender.firstIndex(of: "("), sender.hasSuffix(")") {
            let candSender = String(sender[..<firstParen]).trimmingCharacters(in: .whitespacesAndNewlines)
            let insideParens = String(sender[sender.index(after: firstParen)..<sender.index(before: sender.endIndex)]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !candSender.isEmpty && !insideParens.isEmpty {
                sender = candSender
                group = insideParens
            }
        }

        // Case 4: Chat apps with "SenderName: MessageBody" in body
        let isMessagingApp = bundleIdentifier.contains("whatsapp")
            || appName.localizedCaseInsensitiveContains("whatsapp")
            || appName.localizedCaseInsensitiveContains("telegram")
            || appName.localizedCaseInsensitiveContains("slack")
            || appName.localizedCaseInsensitiveContains("discord")
            || appName.localizedCaseInsensitiveContains("messages")

        if isMessagingApp || group != nil {
            if let colonIdx = message.firstIndex(of: ":") {
                let prefix = String(message[..<colonIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                let rest = String(message[message.index(after: colonIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !prefix.contains("\n") && prefix.count > 0 && prefix.count <= 45 && !rest.isEmpty {
                    if group != nil && (sender == group || sender.isEmpty) {
                        sender = prefix
                        message = rest
                    } else if group == nil && sender != prefix && isMessagingApp {
                        group = sender
                        sender = prefix
                        message = rest
                    }
                }
            }
        }

        // Final cleanup of trailing colons from sender
        while sender.hasSuffix(":") {
            sender = String(sender.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (sender, group, message)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(appName, forKey: .appName)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(sender, forKey: .sender)
        try container.encode(message, forKey: .message)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(groupName, forKey: .groupName)
        try container.encodeIfPresent(avatarData, forKey: .avatarData)
    }

    /// Returns the group name (if this is a group chat notification), or nil if it's a 1-on-1 direct message.
    public var resolvedGroupName: String? {
        if let g = groupName, !g.isEmpty {
            return g
        }
        let parsed = ObeliskNotification.parseSenderAndGroup(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            rawSender: sender,
            rawGroup: groupName,
            rawMessage: message
        )
        return parsed.group
    }

    /// Returns the individual sender name (e.g. "Alex" or "Alpin Pasuruan").
    public var resolvedSenderName: String {
        let parsed = ObeliskNotification.parseSenderAndGroup(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            rawSender: sender,
            rawGroup: groupName,
            rawMessage: message
        )
        return parsed.sender
    }

    public var formattedTimeAgo: String {
        let seconds = Int(-timestamp.timeIntervalSinceNow)
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let mins = max(1, seconds / 60)
            return "\(mins)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: timestamp)
        }
    }

    public static func == (lhs: ObeliskNotification, rhs: ObeliskNotification) -> Bool {
        lhs.id == rhs.id &&
        lhs.appName == rhs.appName &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.sender == rhs.sender &&
        lhs.message == rhs.message &&
        lhs.groupName == rhs.groupName &&
        lhs.avatarData == rhs.avatarData
    }

    // MARK: - Smart Notification Category Classifier

    public var category: NotificationFilterCategory {
        let lowerBundle = bundleIdentifier.lowercased()
        let lowerApp = appName.lowercased()

        // 1. Check LSApplicationCategoryType from app bundle
        if let url = appURL, let bundle = Bundle(url: url),
           let catType = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String {
            let cat = catType.lowercased()
            if cat.contains("social") || cat.contains("news") {
                return .socialMedia
            } else if cat.contains("music") || cat.contains("entertainment") || cat.contains("video") || cat.contains("games") {
                return .entertainment
            } else if cat.contains("productivity") || cat.contains("business") || cat.contains("finance") {
                return .productivity
            } else if cat.contains("developer") {
                return .developer
            }
        }

        // 2. Social & Messaging Apps
        let socialKeywords = [
            "whatsapp", "telegram", "discord", "slack", "messages", "signal",
            "wechat", "line", "instagram", "twitter", "tweet", "mastodon", "bluesky",
            "messenger", "facebook", "viber", "skype", "element", "matrix"
        ]
        if socialKeywords.contains(where: { lowerBundle.contains($0) || lowerApp.contains($0) }) {
            return .socialMedia
        }

        // 3. Entertainment & Media Apps
        let entertainmentKeywords = [
            "spotify", "music", "youtube", "netflix", "tv", "podcast",
            "twitch", "vidio", "tiktok", "vlc", "iina", "quicktime",
            "soundcloud", "hulu", "disney", "primevideo", "steam"
        ]
        if entertainmentKeywords.contains(where: { lowerBundle.contains($0) || lowerApp.contains($0) }) {
            return .entertainment
        }

        // 4. Productivity & Work Apps
        let productivityKeywords = [
            "mail", "calendar", "reminder", "notes", "notion", "trello",
            "asana", "linear", "jira", "confluence", "teams", "zoom",
            "docs", "sheets", "slides", "word", "excel", "powerpoint",
            "outlook", "onenote", "craft", "bear", "obsidian", "todoist", "things"
        ]
        if productivityKeywords.contains(where: { lowerBundle.contains($0) || lowerApp.contains($0) }) {
            return .productivity
        }

        // 5. Developer Tools & Code Editors
        let developerKeywords = [
            "xcode", "terminal", "iterm", "vscode", "visual studio", "cursor",
            "sublime", "intellij", "pycharm", "webstorm", "git", "github",
            "gitlab", "docker", "postman", "simulator", "android"
        ]
        if developerKeywords.contains(where: { lowerBundle.contains($0) || lowerApp.contains($0) }) {
            return .developer
        }

        return .systemAndOther
    }

    /// Checks if this notification matches the user's selected category filter.
    public func matches(filter: NotificationFilterCategory) -> Bool {
        if filter == .all { return true }
        return self.category == filter
    }

    /// Resolves the filesystem URL of the target application on macOS.
    public static func resolveAppURL(bundleIdentifier: String, appName: String) -> URL? {
        if !bundleIdentifier.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }

        let standardAppPaths = [
            "/System/Applications/\(appName).app",
            "/Applications/\(appName).app",
            "/System/Applications/Utilities/\(appName).app",
            "\(NSHomeDirectory())/Applications/\(appName).app"
        ]

        for path in standardAppPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        if let running = NSWorkspace.shared.runningApplications.first(where: {
            (!bundleIdentifier.isEmpty && $0.bundleIdentifier == bundleIdentifier) ||
            ($0.localizedName?.lowercased() == appName.lowercased())
        }), let bundleURL = running.bundleURL {
            return bundleURL
        }

        return nil
    }

    /// Dynamically resolves the high-resolution native AppKit icon of the application.
    public static func resolveIcon(url: URL?, bundleIdentifier: String, appName: String) -> NSImage? {
        if let url = url {
            return NSWorkspace.shared.icon(forFile: url.path)
        }

        if let running = NSWorkspace.shared.runningApplications.first(where: {
            (!bundleIdentifier.isEmpty && $0.bundleIdentifier == bundleIdentifier) ||
            ($0.localizedName?.lowercased() == appName.lowercased())
        }), let icon = running.icon {
            return icon
        }

        return nil
    }
}

