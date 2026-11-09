import AppKit
import Foundation
import Combine
import Darwin
import SQLite3

public struct ActiveDownloadItem: Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let fileURL: URL
    public let currentBytes: Int64
    public let totalBytes: Int64?
    public let progressFraction: Double?
    public let speedFormatted: String

    public static func == (lhs: ActiveDownloadItem, rhs: ActiveDownloadItem) -> Bool {
        lhs.id == rhs.id && lhs.currentBytes == rhs.currentBytes && lhs.progressFraction == rhs.progressFraction && lhs.displayName == rhs.displayName
    }
}

private struct MonitoredDownloadState {
    var firstSeen: Date
    var lastActiveTime: Date
    var lastBytes: Int64
    var stallCount: Int
    var highestFraction: Double
    var resolvedTargetName: String?
    var totalBytes: Int64?
    var lastDBLookupTime: Date
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
    private var progressStates: [URL: MonitoredDownloadState] = [:]
    private var previousFinishedFiles: [URL: (size: Int64, modDate: Date)] = [:]
    private var hasInitializedBaseline: Bool = false

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
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
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
        var currentActiveURLs: Set<URL> = []
        var allDownloadURLsOnDisk: Set<URL> = []
        var currentFinishedFiles: [URL: (size: Int64, modDate: Date)] = [:]

        let now = Date()

        for url in contents {
            let ext = url.pathExtension.lowercased()
            let isDownload = (ext == "crdownload" || ext == "download" || ext == "part")
            if !isDownload {
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path) {
                    let size = (attrs[.size] as? Int64) ?? 0
                    let modDate = (attrs[.modificationDate] as? Date) ?? .distantPast
                    currentFinishedFiles[url] = (size, modDate)
                }
                continue
            }

            allDownloadURLsOnDisk.insert(url)

            var currentBytes: Int64 = 0
            var totalBytes: Int64? = nil
            var modDate: Date = now

            if ext == "download" {
                // Safari package bundle inspect
                let (cur, tot) = readSafariDownloadProgress(packageURL: url)
                currentBytes = cur
                totalBytes = tot
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                   let mDate = attrs[.modificationDate] as? Date {
                    modDate = mDate
                }
            } else {
                // Chrome / Edge / Firefox single file size & live modification date (bypassing URL resource cache)
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path) {
                    if let size = attrs[.size] as? Int64 {
                        currentBytes = size
                    }
                    if let mDate = attrs[.modificationDate] as? Date {
                        modDate = mDate
                    }
                }
                if let cached = cachedTotalSizes[url] {
                    totalBytes = cached
                } else {
                    requestTotalSizeIfAvailable(for: url)
                }
            }

            let timeSinceMod = now.timeIntervalSince(modDate)
            let isFirstSeen = (progressStates[url] == nil)

            var state = progressStates[url] ?? MonitoredDownloadState(
                firstSeen: now,
                lastActiveTime: now,
                lastBytes: currentBytes,
                // If an old leftover .crdownload file was modified > 2.0s ago when first seen, mark it stalled immediately
                stallCount: timeSinceMod > 2.0 ? 10 : 0,
                highestFraction: 0.02,
                resolvedTargetName: nil,
                totalBytes: totalBytes,
                lastDBLookupTime: .distantPast
            )

            // Query Chromium History SQLite DB if totalBytes or targetName is still needed
            if ext == "crdownload" && (state.totalBytes == nil || state.resolvedTargetName == nil) && now.timeIntervalSince(state.lastDBLookupTime) > 1.0 {
                state.lastDBLookupTime = now
                if let meta = Self.readChromiumDownloadMetadata(for: url) {
                    if meta.isCancelled {
                        state.stallCount = 10
                        progressStates[url] = state
                        continue
                    }
                    if let tName = meta.targetName, !tName.isEmpty {
                        state.resolvedTargetName = tName
                    }
                    if let tBytes = meta.totalBytes, tBytes > 0 {
                        state.totalBytes = tBytes
                        cachedTotalSizes[url] = tBytes
                    }
                }
            }

            if let sTot = state.totalBytes, sTot > 0 {
                totalBytes = sTot
            }

            let deltaBytes = currentBytes - state.lastBytes

            // Inactivity / Cancellation Detection:
            // If bytes are actively increasing, reset stallCount.
            // If bytes stopped increasing, increment stallCount on every tick (after the initial creation tick).
            // Once stallCount reaches 4 (~1.4 seconds of zero byte growth), immediately dismiss from activeDownloads.
            if deltaBytes > 0 {
                state.stallCount = 0
                state.lastActiveTime = now
                state.lastBytes = currentBytes
            } else if !isFirstSeen {
                state.stallCount += 1
            }

            if state.stallCount >= 4 {
                progressStates[url] = state
                continue
            }

            currentActiveURLs.insert(url)

            let cleanName = state.resolvedTargetName ?? cleanDownloadName(for: url)

            // Calculate download speed
            var speedStr = ""
            if let prev = previousByteCounts[url] {
                let bytesChange = Double(currentBytes - prev.bytes)
                let deltaTime = now.timeIntervalSince(prev.timestamp)
                if deltaTime > 0.15 && bytesChange > 0 {
                    let bytesPerSec = bytesChange / deltaTime
                    speedStr = formatSpeed(bytesPerSec)
                }
            }
            previousByteCounts[url] = (currentBytes, now)

            // Calculate smooth, strictly non-decreasing progress fraction (0.01 ... 0.99)
            let fraction: Double
            if let tot = totalBytes, tot > 0 {
                let exactFrac = max(0.01, min(0.99, Double(currentBytes) / Double(tot)))
                state.highestFraction = max(state.highestFraction, exactFrac)
                fraction = state.highestFraction
            } else {
                // Smooth velocity-controlled progression when Content-Length is not exposed on disk:
                // Advances steadily from left to right only while bytes are actively arriving (deltaBytes > 0).
                if deltaBytes > 0 {
                    let step: Double
                    if state.highestFraction < 0.50 {
                        step = 0.018
                    } else if state.highestFraction < 0.80 {
                        step = 0.010
                    } else {
                        step = 0.004
                    }
                    state.highestFraction = min(0.95, state.highestFraction + step)
                }
                fraction = state.highestFraction
            }
            progressStates[url] = state

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

        if !hasInitializedBaseline {
            previousFinishedFiles = currentFinishedFiles
            hasInitializedBaseline = true
        }

        // Clean up state for download files that have been completely removed from disk
        let removedFromDisk = Set(progressStates.keys).subtracting(allDownloadURLsOnDisk)
        let disappearedActiveURLs = knownActiveURLs.subtracting(currentActiveURLs)
        let appearedActiveURLs = currentActiveURLs.subtracting(knownActiveURLs)

        var trulyFinishedURLs: [(url: URL, lastSize: Int64, targetName: String?)] = []
        for disappeared in disappearedActiveURLs {
            let lower = disappeared.lastPathComponent.lowercased()
            // In-flight rename by Chrome from Unconfirmed XXXXX.crdownload to actual filename.crdownload
            if lower.hasPrefix("unconfirmed") && !appearedActiveURLs.isEmpty {
                if let newURL = appearedActiveURLs.first {
                    if let st = progressStates[disappeared] {
                        progressStates[newURL] = st
                    }
                    if let prev = previousByteCounts[disappeared] {
                        previousByteCounts[newURL] = prev
                    }
                    if let cached = cachedTotalSizes[disappeared] {
                        cachedTotalSizes[newURL] = cached
                    }
                }
                progressStates.removeValue(forKey: disappeared)
                previousByteCounts.removeValue(forKey: disappeared)
                cachedTotalSizes.removeValue(forKey: disappeared)
                pendingTotalSizeLookups.remove(disappeared)
                continue
            }

            // Only evaluate completion if the .crdownload/.download/.part file was actually removed/renamed from disk.
            // If it is still on disk (i.e. paused or stalled), we simply let activeDownloads clear so the standby notch closes.
            if !allDownloadURLsOnDisk.contains(disappeared) {
                let lastSize = previousByteCounts[disappeared]?.bytes ?? progressStates[disappeared]?.lastBytes ?? 0
                let targetName = progressStates[disappeared]?.resolvedTargetName
                trulyFinishedURLs.append((disappeared, lastSize, targetName))
            }
        }

        for goneURL in removedFromDisk {
            progressStates.removeValue(forKey: goneURL)
            previousByteCounts.removeValue(forKey: goneURL)
            cachedTotalSizes.removeValue(forKey: goneURL)
            pendingTotalSizeLookups.remove(goneURL)
        }

        // Snapshot baseline finished files BEFORE updating previousFinishedFiles
        let baselineSnapshot = self.previousFinishedFiles
        self.previousFinishedFiles = currentFinishedFiles

        // Process completed downloads (cancelled downloads are dismissed immediately without alert)
        for finished in trulyFinishedURLs {
            resolveAndNotifyCompletion(
                finishedURL: finished.url,
                lastKnownSize: finished.lastSize,
                knownTargetName: finished.targetName,
                baselineFiles: baselineSnapshot
            )
        }

        let wasDownloading = self.isDownloading
        self.knownActiveURLs = currentActiveURLs
        self.activeDownloads = currentActive
        self.isDownloading = !currentActive.isEmpty

        if wasDownloading != self.isDownloading || self.isDownloading {
            WindowManager.shared.updateCompactWidth(animated: true)
        }

        // Standby summary format: percentage only (e.g. "45%")
        if let first = currentActive.first {
            let frac = first.progressFraction ?? 0.0
            self.standbySummaryText = "\(Int(round(frac * 100)))%"
        } else {
            self.standbySummaryText = ""
        }
    }

    private func resolveAndNotifyCompletion(
        finishedURL: URL,
        lastKnownSize: Int64,
        knownTargetName: String?,
        baselineFiles: [URL: (size: Int64, modDate: Date)]
    ) {
        // Allow 350ms for atomic rename and macOS quarantine/Gatekeeper processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard self != nil else { return }
            guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }

            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { return }

            // Find any finished file in ~/Downloads that is NEW or UPDATED compared to baselineSnapshot
            // taken while the download was still in progress!
            // If the user cancelled the download, NO new finished file appears in ~/Downloads.
            var newlyCompletedFiles: [(url: URL, size: Int64, sizeDiff: Int64, modDate: Date)] = []

            for url in files {
                let ext = url.pathExtension.lowercased()
                guard ext != "crdownload" && ext != "download" && ext != "part" else { continue }
                guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                      let fileSize = attrs[.size] as? Int64,
                      fileSize > 0 else { continue }

                let modDate = (attrs[.modificationDate] as? Date) ?? .distantPast

                let isNewOrModified: Bool
                if let old = baselineFiles[url] {
                    // Existed before: only count as newly completed if its size or modification date changed just now
                    isNewOrModified = (old.size != fileSize || abs(old.modDate.timeIntervalSince(modDate)) > 0.5)
                } else {
                    // Brand new file that did not exist in ~/Downloads while .crdownload was active!
                    isNewOrModified = true
                }

                guard isNewOrModified else { continue }

                // Verify the completed file is at least as large as the bytes downloaded before completion
                if lastKnownSize > 0 && fileSize + 65536 < lastKnownSize {
                    continue
                }

                let sizeDiff = abs(fileSize - lastKnownSize)
                newlyCompletedFiles.append((url, fileSize, sizeDiff, modDate))
            }

            // If no new file appeared in ~/Downloads, the download was cancelled/aborted — do nothing!
            guard let bestMatch = newlyCompletedFiles.min(by: {
                if $0.sizeDiff != $1.sizeDiff {
                    return $0.sizeDiff < $1.sizeDiff
                }
                return $0.modDate > $1.modDate
            }) else {
                return
            }

            let resolvedName = bestMatch.url.lastPathComponent.isEmpty
                ? (knownTargetName ?? "Download")
                : bestMatch.url.lastPathComponent

            HardwareTelemetryService.shared.triggerTransientHUD(
                .download(
                    fileName: resolvedName,
                    statusText: "Download Complete",
                    isSuccess: true,
                    progress: 1.0
                ),
                duration: 3.5
            )
        }
    }

    nonisolated private static func readChromiumDownloadMetadata(
        for fileURL: URL
    ) -> (targetName: String?, totalBytes: Int64?, isCancelled: Bool)? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support")
        let browserRoots = [
            appSupport.appendingPathComponent("Google/Chrome"),
            appSupport.appendingPathComponent("BraveSoftware/Brave-Browser"),
            appSupport.appendingPathComponent("Microsoft Edge"),
            appSupport.appendingPathComponent("Arc/User Data")
        ]

        var candidateHistories: [(url: URL, modDate: Date)] = []
        for root in browserRoots {
            guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            for item in items {
                let name = item.lastPathComponent
                guard name == "Default" || name.hasPrefix("Profile ") else { continue }
                let historyURL = item.appendingPathComponent("History")
                if let attrs = try? fm.attributesOfItem(atPath: historyURL.path),
                   let modDate = attrs[.modificationDate] as? Date {
                    candidateHistories.append((historyURL, modDate))
                }
            }
        }

        // Check most recently modified History databases first (at most top 3)
        candidateHistories.sort { $0.modDate > $1.modDate }
        let fileName = fileURL.lastPathComponent

        for candidate in candidateHistories.prefix(3) {
            let tempCopy = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("obelisk_dl_\(ProcessInfo.processInfo.processIdentifier).sqlite")
            try? fm.removeItem(at: tempCopy)
            guard (try? fm.copyItem(at: candidate.url, to: tempCopy)) != nil else { continue }
            defer { try? fm.removeItem(at: tempCopy) }

            var db: OpaquePointer?
            guard sqlite3_open_v2(tempCopy.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
                  let validDB = db else {
                if let db = db { sqlite3_close(db) }
                continue
            }
            defer { sqlite3_close(validDB) }

            let query = "SELECT current_path, target_path, total_bytes, state FROM downloads ORDER BY id DESC LIMIT 10;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(validDB, query, -1, &stmt, nil) == SQLITE_OK,
                  let validStmt = stmt else {
                continue
            }
            defer { sqlite3_finalize(validStmt) }

            while sqlite3_step(validStmt) == SQLITE_ROW {
                let curPath = sqlite3_column_text(validStmt, 0).map { String(cString: $0) } ?? ""
                let tgtPath = sqlite3_column_text(validStmt, 1).map { String(cString: $0) } ?? ""
                let totBytes = sqlite3_column_int64(validStmt, 2)
                let state = sqlite3_column_int(validStmt, 3)

                if curPath == fileURL.path || URL(fileURLWithPath: curPath).lastPathComponent == fileName {
                    let targetName = tgtPath.isEmpty ? nil : URL(fileURLWithPath: tgtPath).lastPathComponent
                    let totalOpt: Int64? = totBytes > 0 ? totBytes : nil
                    let isCancelled = (state == 2 || state == 3 || state == 4)
                    return (targetName, totalOpt, isCancelled)
                }
            }
        }
        return nil
    }

    private func cleanDownloadName(for url: URL) -> String {
        var base = url.deletingPathExtension().lastPathComponent
        if base.lowercased().hasSuffix(".crdownload") || base.lowercased().hasSuffix(".download") || base.lowercased().hasSuffix(".part") {
            base = (base as NSString).deletingPathExtension
        }
        if base.lowercased().hasPrefix("unconfirmed") {
            return "Downloading..."
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

