import AppKit
import Foundation
import Combine
import Darwin

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
    private var cachedTotalSizes: [URL: Int64] = [:]
    private var pendingTotalSizeLookups: Set<URL> = []

    private init() {
        startMonitoring()

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

    public func startMonitoring() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scanDownloadsFolder()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
        scanDownloadsFolder()
    }

    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
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
                if let cached = cachedTotalSizes[url] {
                    totalBytes = cached
                } else {
                    requestTotalSizeIfAvailable(for: url)
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

        // Detect disappeared URLs
        let disappearedURLs = knownActiveURLs.subtracting(currentURLs)
        let appearedURLs = currentURLs.subtracting(knownActiveURLs)

        var trulyFinishedURLs: [URL] = []
        for disappeared in disappearedURLs {
            let lower = disappeared.lastPathComponent.lowercased()
            // In-flight rename by Chrome from Unconfirmed XXXXX.crdownload to actual filename.crdownload
            if lower.hasPrefix("unconfirmed") && !appearedURLs.isEmpty {
                if let newURL = appearedURLs.first {
                    if let prev = previousByteCounts[disappeared] {
                        previousByteCounts[newURL] = prev
                    }
                    if let cached = cachedTotalSizes[disappeared] {
                        cachedTotalSizes[newURL] = cached
                    }
                }
                previousByteCounts.removeValue(forKey: disappeared)
                cachedTotalSizes.removeValue(forKey: disappeared)
                pendingTotalSizeLookups.remove(disappeared)
                continue
            }
            trulyFinishedURLs.append(disappeared)
        }

        // Process completed or cancelled downloads
        for finishedURL in trulyFinishedURLs {
            let lastSize = previousByteCounts[finishedURL]?.bytes ?? 0
            previousByteCounts.removeValue(forKey: finishedURL)
            cachedTotalSizes.removeValue(forKey: finishedURL)
            pendingTotalSizeLookups.remove(finishedURL)

            resolveAndNotifyCompletion(finishedURL: finishedURL, lastKnownSize: lastSize)
        }

        let wasDownloading = self.isDownloading
        self.knownActiveURLs = currentURLs
        self.activeDownloads = currentActive
        self.isDownloading = !currentActive.isEmpty

        if wasDownloading != self.isDownloading || self.isDownloading {
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

    private func resolveAndNotifyCompletion(finishedURL: URL, lastKnownSize: Int64) {
        let rawName = cleanDownloadName(for: finishedURL)

        // Allow 350ms for atomic rename and macOS quarantine/Gatekeeper processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard self != nil else { return }
            guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }

            let fileManager = FileManager.default
            let finalTargetURL = finishedURL.deletingPathExtension()

            var resolvedName = rawName
            var isSuccess = false

            // Check 1: Direct target file exists and was modified recently (within 15 seconds)
            if fileManager.fileExists(atPath: finalTargetURL.path) {
                if let modDate = (try? fileManager.attributesOfItem(atPath: finalTargetURL.path))?[.modificationDate] as? Date,
                   modDate.timeIntervalSinceNow > -15.0 {
                    resolvedName = finalTargetURL.lastPathComponent
                    isSuccess = true
                } else if !fileManager.fileExists(atPath: finalTargetURL.path) {
                    isSuccess = false
                } else {
                    isSuccess = true
                    resolvedName = finalTargetURL.lastPathComponent
                }
            }

            // Check 2: If not verified or if it was an "Unconfirmed" Chrome placeholder,
            // inspect the Downloads folder for any file created or modified in the last 6 seconds
            if !isSuccess || resolvedName.lowercased().hasPrefix("unconfirmed") {
                if let files = try? fileManager.contentsOfDirectory(
                    at: downloadsURL,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                ) {
                    let cutoff = Date().addingTimeInterval(-6.0)
                    let recentFiles = files.compactMap { url -> (url: URL, date: Date, size: Int64)? in
                        let ext = url.pathExtension.lowercased()
                        guard ext != "crdownload" && ext != "download" && ext != "part" else { return nil }
                        guard let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                              let modDate = vals.contentModificationDate,
                              modDate > cutoff,
                              let fileSize = vals.fileSize,
                              fileSize > 0 else {
                            return nil
                        }
                        return (url, modDate, Int64(fileSize))
                    }

                    if let newest = recentFiles.max(by: { $0.date < $1.date }) {
                        resolvedName = newest.url.lastPathComponent
                        isSuccess = true
                    }
                }
            }

            // Clean up placeholder names if still unresolved
            if resolvedName.lowercased().hasPrefix("unconfirmed") {
                resolvedName = isSuccess ? "File" : "Download"
            }

            let statusText = isSuccess ? "Download Complete" : "Download Failed"

            HardwareTelemetryService.shared.triggerTransientHUD(
                .download(
                    fileName: resolvedName,
                    statusText: statusText,
                    isSuccess: isSuccess,
                    progress: nil
                ),
                duration: 3.5
            )
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
        var current: Int64 = 0
        var total: Int64? = nil

        if let data = try? Data(contentsOf: plistURL),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            current = (dict["NSURLDownloadBytesReceived"] as? NSNumber)?.int64Value ?? 0
            total = (dict["NSURLDownloadTotalBytesExpected"] as? NSNumber)?.int64Value
        }

        // Fallback: measure actual payload size inside package if current is reported as 0
        if current == 0 {
            if let files = try? FileManager.default.contentsOfDirectory(at: packageURL, includingPropertiesForKeys: [.fileSizeKey]) {
                for file in files where file.lastPathComponent != "Info.plist" {
                    if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                        current += Int64(size)
                    }
                }
            }
        }
        return (current, total)
    }

    nonisolated private static func readSourceURL(for fileURL: URL) -> URL? {
        let key = "com.apple.metadata:kMDItemWhereFroms"
        let length = getxattr(fileURL.path, key, nil, 0, 0, 0)
        guard length > 0 else { return nil }
        var data = Data(count: length)
        let readLen = data.withUnsafeMutableBytes { ptr in
            getxattr(fileURL.path, key, ptr.baseAddress, length, 0, 0)
        }
        guard readLen == length else { return nil }
        guard let list = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String],
              let first = list.first,
              let url = URL(string: first),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    private func requestTotalSizeIfAvailable(for url: URL) {
        guard !pendingTotalSizeLookups.contains(url), cachedTotalSizes[url] == nil else { return }
        pendingTotalSizeLookups.insert(url)

        let targetURL = url
        Task.detached(priority: .utility) { [weak self] in
            guard let sourceURL = Self.readSourceURL(for: targetURL) else { return }
            var req = URLRequest(url: sourceURL)
            req.httpMethod = "HEAD"
            req.timeoutInterval = 3.5

            let session = URLSession(configuration: .ephemeral)
            guard let (_, response) = try? await session.data(for: req),
                  let http = response as? HTTPURLResponse,
                  http.statusCode >= 200 && http.statusCode < 400,
                  http.expectedContentLength > 0 else {
                return
            }

            let length = http.expectedContentLength
            await MainActor.run { [weak self] in
                self?.cachedTotalSizes[targetURL] = length
            }
        }
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
