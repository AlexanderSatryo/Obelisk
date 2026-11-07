import AppKit
import Foundation

/// Represents an incoming rich notification displayed via the Dynamic Island notch HUD.
public struct ObeliskNotification: Identifiable, Equatable {
    public let id: UUID
    public let appName: String
    public let bundleIdentifier: String
    public let sender: String
    public let message: String
    public let timestamp: Date
    public let appIcon: NSImage?
    public let appURL: URL?

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
