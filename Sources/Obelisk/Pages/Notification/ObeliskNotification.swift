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

    enum CodingKeys: String, CodingKey {
        case id, appName, bundleIdentifier, sender, message, timestamp
    }

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String = "",
        sender: String,
        message: String,
        timestamp: Date = Date(),
        appIcon: NSImage? = nil,
        appURL: URL? = nil
    ) {
        let cleanAppName = ObeliskNotification.stripBidiControlMarks(appName)
        let cleanSender = ObeliskNotification.stripBidiControlMarks(sender)
        let cleanMessage = ObeliskNotification.stripBidiControlMarks(message)

        self.id = id
        self.appName = cleanAppName
        self.bundleIdentifier = bundleIdentifier
        self.sender = cleanSender
        self.message = cleanMessage
        self.timestamp = timestamp

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

        let cleanAppName = ObeliskNotification.stripBidiControlMarks(rawAppName)
        self.appName = cleanAppName
        self.sender = ObeliskNotification.stripBidiControlMarks(rawSender)
        self.message = ObeliskNotification.stripBidiControlMarks(rawMessage)

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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(appName, forKey: .appName)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(sender, forKey: .sender)
        try container.encode(message, forKey: .message)
        try container.encode(timestamp, forKey: .timestamp)
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
        lhs.message == rhs.message
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

