import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Represents a file temporarily staged on the Obelisk File Tray shelf.
public struct TrayFile: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let sizeFormatted: String
    public let iconImage: NSImage
    public let addedAt: Date

    public static func == (lhs: TrayFile, rhs: TrayFile) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}

/// Thread-safe collector for incoming dropped URLs across concurrent asynchronous item provider calls.
public final class URLDropCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []

    public init() {}

    public func append(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }

    public func collect() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }
}

/// Receives completion callbacks from the system AirDrop sharing service.
private final class AirDropSharingDelegate: NSObject, NSSharingServiceDelegate {
    var onDidShare: (() -> Void)?

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        let callback = onDidShare
        DispatchQueue.main.async { callback?() }
    }
}

/// Central service managing the Obelisk File Tray and native AirDrop integration.
/// Allows dragging and dropping files onto the notch, staging them temporarily,
/// dragging them out to Finder/apps, or sharing directly via macOS AirDrop.
@MainActor
public final class FileTrayService: ObservableObject {
    public static let shared = FileTrayService()

    @Published public private(set) var files: [TrayFile] = []
    @Published public var isTargetedForDrop: Bool = false
    @Published public var lastStatusMessage: String? = nil

    private let airDropDelegate = AirDropSharingDelegate()

    private init() {}

    /// Adds multiple file URLs into the shelf, skipping duplicates.
    public func addFiles(urls: [URL]) {
        var addedCount = 0
        for url in urls {
            // Normalize URL
            let standardized = url.standardizedFileURL
            if files.contains(where: { $0.url.path == standardized.path }) {
                continue
            }

            let name = standardized.lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: standardized.path)
            icon.size = NSSize(width: 32, height: 32)

            let sizeStr = formatFileSize(url: standardized)

            let item = TrayFile(
                id: UUID(),
                url: standardized,
                name: name,
                sizeFormatted: sizeStr,
                iconImage: icon,
                addedAt: Date()
            )
            files.insert(item, at: 0)
            addedCount += 1
        }

        // Enforce the user-configured shelf capacity, discarding the oldest staged files first.
        let capacity = max(1, ObeliskSettings.shared.fileTrayCapacity)
        if files.count > capacity {
            files.removeLast(files.count - capacity)
        }

        if addedCount > 0 {
            lastStatusMessage = "Added \(addedCount) file\(addedCount > 1 ? "s" : "") to tray"
        }
    }

    /// Removes a specific file from the tray shelf.
    public func removeFile(id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            files.removeAll(where: { $0.id == id })
        }
    }

    /// Empties all files from the tray shelf.
    public func clearAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            files.removeAll()
            lastStatusMessage = nil
        }
    }

    /// Opens macOS file dialog so user can pick files to put onto the shelf.
    public func promptAddFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add to Shelf"
        panel.message = "Choose files or folders to stage in Obelisk File Tray"

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            addFiles(urls: panel.urls)
        }
    }

    /// Initiates a native macOS AirDrop transfer for the specified files or all files in the shelf.
    public func shareViaAirDrop(targetFiles: [URL]? = nil) {
        let itemsToSend: [URL]
        if let target = targetFiles, !target.isEmpty {
            itemsToSend = target
        } else if !files.isEmpty {
            itemsToSend = files.map(\.url)
        } else {
            // If tray is empty, allow user to browse and pick a file to AirDrop immediately
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = true
            panel.prompt = "AirDrop"
            panel.message = "Select files to share via AirDrop"

            NSApp.activate(ignoringOtherApps: true)
            if panel.runModal() == .OK {
                itemsToSend = panel.urls
            } else {
                return
            }
        }

        guard !itemsToSend.isEmpty else { return }

        if let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: itemsToSend) {
            let sentFromShelf = targetFiles == nil || files.contains(where: { f in itemsToSend.contains(where: { $0.path == f.url.path }) })
            airDropDelegate.onDidShare = { [weak self] in
                Task { @MainActor in
                    guard let self, sentFromShelf, ObeliskSettings.shared.autoClearAfterAirDrop else { return }
                    self.clearAll()
                }
            }
            service.delegate = airDropDelegate
            service.perform(withItems: itemsToSend)
        } else {
            // Fallback to generic share picker
            if let window = NSApp.keyWindow {
                let picker = NSSharingServicePicker(items: itemsToSend)
                picker.show(relativeTo: .zero, of: window.contentView ?? NSView(), preferredEdge: .minY)
            }
        }
    }

    /// Reveals a staged file in macOS Finder.
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens the staged file with its default application.
    public func openFile(url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func formatFileSize(url: URL) -> String {
        do {
            let res = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if res.isDirectory == true {
                return "Folder"
            }
            if let bytes = res.fileSize {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useAll]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(bytes))
            }
        } catch {}
        return "Unknown"
    }
}

