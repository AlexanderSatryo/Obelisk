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
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.sender = sender
        self.message = message
        self.timestamp = timestamp

        let resolvedURL = appURL ?? ObeliskNotification.resolveAppURL(bundleIdentifier: bundleIdentifier, appName: appName)
        self.appURL = resolvedURL
        self.appIcon = appIcon ?? ObeliskNotification.resolveIcon(url: resolvedURL, bundleIdentifier: bundleIdentifier, appName: appName)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.appName = try container.decode(String.self, forKey: .appName)
        self.bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        self.sender = try container.decode(String.self, forKey: .sender)
        self.message = try container.decode(String.self, forKey: .message)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)

        let resolvedURL = ObeliskNotification.resolveAppURL(bundleIdentifier: bundleIdentifier, appName: appName)
        self.appURL = resolvedURL
        self.appIcon = ObeliskNotification.resolveIcon(url: resolvedURL, bundleIdentifier: bundleIdentifier, appName: appName)
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

