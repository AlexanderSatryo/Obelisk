import AppKit
import Foundation
import Combine

public struct ActiveDownloadItem: Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let fileURL: URL
    public let currentBytes: Int64
    public let totalBytes: Int64?
    public let progressFraction: Double?
    public let speedFormatted: String

    public static func == (lhs: ActiveDownloadItem, rhs: ActiveDownloadItem) -> Bool {
        lhs.id == rhs.id && lhs.currentBytes == rhs.currentBytes
    }
}

/// Monitors macOS user Downloads folder for active browser downloads (Safari, Chrome, Brave, Arc, Firefox).
/// Dispatches real-time download progress to the standby notch wings and triggers completion alerts.
@MainActor
public final class DownloadMonitorService: ObservableObject {
    public static let shared = DownloadMonitorService()

    @Published public var activeDownloads: [ActiveDownloadItem] = []
    @Published public var isDownloading: Bool = false
    @Published public var standbySummaryText: String = ""

    private var pollTimer: Timer?
    private var knownActiveURLs: Set<URL> = []
    private var previousByteCounts: [URL: (bytes: Int64, timestamp: Date)] = [:]

    private init() {
        startMonitoring()
    }

    public func startMonitoring() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanDownloadsFolder()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
        scanDownloadsFolder()
    }

    private func scanDownloadsFolder() {
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }

        let fileManager = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        guard let contents = try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: options
        ) else { return }

        var currentActive: [ActiveDownloadItem] = []
        var currentURLs: Set<URL> = []

        let now = Date()

        for url in contents {
            let ext = url.pathExtension.lowercased()
            let isDownload = (ext == "crdownload" || ext == "download" || ext == "part")
            guard isDownload else { continue }

            currentURLs.insert(url)

            let cleanName = cleanDownloadName(for: url)
            var currentBytes: Int64 = 0
            var totalBytes: Int64? = nil

            if ext == "download" {
                // Safari package bundle inspect
                let (cur, tot) = readSafariDownloadProgress(packageURL: url)
                currentBytes = cur
                totalBytes = tot
            } else {
                // Chrome / Edge / Firefox single file size
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    currentBytes = size
                }
            }

            // Calculate download speed
            var speedStr = ""
            if let prev = previousByteCounts[url] {
                let deltaBytes = Double(currentBytes - prev.bytes)
                let deltaTime = now.timeIntervalSince(prev.timestamp)
                if deltaTime > 0.2 && deltaBytes > 0 {
                    let bytesPerSec = deltaBytes / deltaTime
                    speedStr = formatSpeed(bytesPerSec)
                }
            }
            previousByteCounts[url] = (currentBytes, now)

            let fraction: Double?
            if let tot = totalBytes, tot > 0 {
                fraction = max(0, min(1.0, Double(currentBytes) / Double(tot)))
            } else {
                fraction = nil
            }

            let item = ActiveDownloadItem(
                id: url.path,
                displayName: cleanName,
                fileURL: url,
                currentBytes: currentBytes,
                totalBytes: totalBytes,
                progressFraction: fraction,
                speedFormatted: speedStr
            )
            currentActive.append(item)
        }

        // Detect finished downloads
        for finishedURL in knownActiveURLs.subtracting(currentURLs) {
            let finishedName = cleanDownloadName(for: finishedURL)
            previousByteCounts.removeValue(forKey: finishedURL)

            // Check if final destination file exists (success) or was deleted/cancelled (failed)
            let finalTargetURL = finishedURL.deletingPathExtension()
            let finalExists = fileManager.fileExists(atPath: finalTargetURL.path)
            let statusText = finalExists ? "Download Complete" : "Download Failed"

            // Trigger elegant completion banner inside the notch
            HardwareTelemetryService.shared.triggerTransientHUD(
                .download(
                    fileName: finishedName,
                    statusText: statusText,
                    isSuccess: finalExists,
                    progress: nil
                ),
                duration: 3.5
            )
        }

        let wasDownloading = self.isDownloading
        self.knownActiveURLs = currentURLs
        self.activeDownloads = currentActive
        self.isDownloading = !currentActive.isEmpty

        if wasDownloading != self.isDownloading {
            WindowManager.shared.updateCompactWidth(animated: true)
        }

        // Standby summary format: e.g. "64%" or "176 MB"
        if let first = currentActive.first {
            if let frac = first.progressFraction {
                self.standbySummaryText = "\(Int(round(frac * 100)))%"
            } else {
                self.standbySummaryText = Self.formatFileSize(first.currentBytes)
            }
        } else {
            self.standbySummaryText = ""
        }
    }

    private func cleanDownloadName(for url: URL) -> String {
        var base = url.deletingPathExtension().lastPathComponent
        if base.lowercased().hasSuffix(".crdownload") || base.lowercased().hasSuffix(".download") {
            base = (base as NSString).deletingPathExtension
        }
        return base
    }

    private func readSafariDownloadProgress(packageURL: URL) -> (current: Int64, total: Int64?) {
        let plistURL = packageURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return (0, nil)
        }

        let current = (dict["NSURLDownloadBytesReceived"] as? Int64) ?? 0
        let total = dict["NSURLDownloadTotalBytesExpected"] as? Int64
        return (current, total)
    }

    public static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        let mb = bytesPerSec / 1_048_576.0
        if mb >= 1.0 {
            return String(format: "%.1f MB/s", mb)
        }
        let kb = bytesPerSec / 1_024.0
        return String(format: "%.0f KB/s", kb)
    }
}
