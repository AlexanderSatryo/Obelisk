import Foundation
import AppKit
import CoreGraphics
import Combine
import SwiftUI

@MainActor
public final class MediaManager: ObservableObject {
    public static let shared = MediaManager()

    @Published public var currentTrack: TrackInfo = .empty
    @Published public var artworkImage: NSImage? {
        didSet {
            if let img = artworkImage {
                self.artworkAccentColor = img.dominantAccentColor()
            } else {
                self.artworkAccentColor = nil
            }
        }
    }
    @Published public var artworkAccentColor: Color? = nil
    @Published public var sourceLogoImage: NSImage?

    private var lastActiveSource: PlayerSource = .none

    // Player tracking for "most recently played" selection
    private var playerPlaybackStartTimes: [String: Date] = [:]
    private var playerPlaybackActiveTimes: [String: Date] = [:]
    private var sourcePlaybackStartTimes: [PlayerSource: Date] = [:]
    private var sourcePlaybackActiveTimes: [PlayerSource: Date] = [:]
    private var previousPlayingStates: [String: Bool] = [:]

    private var lastManualSeekTime: Date = .distantPast
    private var manualSeekTargetPosition: Double = 0
    private var lastUserToggleTime: Date = .distantPast
    private var lastLoadedArtworkPath: String = ""
    private var lastArtworkKey: String = ""

    private init() {
        setupAppSwitchObserver()
        setupTerminationObserver()
        _ = MediaArtworkService.shared
        _ = MediaRemoteBridge.shared
    }

    // MARK: - Safe App State Checkers
    private func isAppRunningAndActive(_ bundleId: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleId && !$0.isTerminated
        }
    }

    private func isSpotifyRunning() -> Bool {
        return isAppRunningAndActive("com.spotify.client")
    }

    // MARK: - Cursor Visibility Guard
    public func keepCursorVisible() {
        NSCursor.setHiddenUntilMouseMoves(false)
        NSCursor.unhide()
        CGDisplayShowCursor(CGMainDisplayID())
    }

    // MARK: - Observers for Termination & App Switching
    private func setupTerminationObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.bundleIdentifier == "com.spotify.client" {
                Task { @MainActor in
                    self?.handleSpotifyTerminated()
                }
            } else if app.bundleIdentifier == "com.apple.Music" {
                Task { @MainActor in
                    if self?.currentTrack.source == .appleMusic {
                        self?.currentTrack = .empty
                        self?.artworkImage = nil
                        self?.sourceLogoImage = nil
                        WindowManager.shared.updateCompactWidth()
                    }
                }
            }
        }
    }

    private func handleSpotifyTerminated() {
        if self.currentTrack.source == .spotify {
            self.currentTrack = .empty
            self.artworkImage = nil
            self.sourceLogoImage = nil
            WindowManager.shared.updateCompactWidth()
        }
    }

    private func setupAppSwitchObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let name = (app.localizedName ?? "").lowercased()
            let bundle = (app.bundleIdentifier ?? "").lowercased()
            MainActor.assumeIsolated {
                self?.handleApplicationActivated(name: name, bundle: bundle)
            }
        }
    }

    private func handleApplicationActivated(name: String, bundle: String) {
        if bundle == "com.google.chrome" || bundle == "com.apple.safari" {
            if !checkBrowserTabMedia() {
                handleSidecarPlayersUpdate(MediaRemoteBridge.shared.getLatestPlayers())
            }
        } else {
            handleSidecarPlayersUpdate(MediaRemoteBridge.shared.getLatestPlayers())
        }
    }

    private func lastPlaybackStartTime(for p: RemoteMediaState) -> Date {
        let keyDate = playerPlaybackStartTimes[p.key] ?? .distantPast
        let srcDate = sourcePlaybackStartTimes[classifySource(for: p)] ?? .distantPast
        return max(keyDate, srcDate)
    }

    private func lastPlaybackActiveTime(for p: RemoteMediaState) -> Date {
        let keyDate = playerPlaybackActiveTimes[p.key] ?? .distantPast
        let srcDate = sourcePlaybackActiveTimes[classifySource(for: p)] ?? .distantPast
        return max(keyDate, srcDate)
    }

    // MARK: - Real-Time Sidecar Stream Handler (Every 0.4s & Instant Notifications)
    public func handleSidecarPlayersUpdate(_ players: [RemoteMediaState]) {
        // Filter out terminated Spotify sessions so Spotify can quit cleanly
        let validPlayers = players.filter { p in
            if p.bundleIdentifier.lowercased().contains("spotify") && !isSpotifyRunning() {
                return false
            }
            return !p.title.isEmpty || p.duration > 0
        }

        guard !validPlayers.isEmpty else {
            // If Chrome/Safari has an active DOM video, check it as fallback
            let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
            if frontBundle == "com.google.Chrome" || frontBundle == "com.apple.Safari" {
                _ = checkBrowserTabMedia()
            }
            return
        }

        let now = Date()

        // 1. Detect state transitions to update last played timestamps
        for p in validPlayers {
            let wasPlaying = previousPlayingStates[p.key] ?? false
            let src = classifySource(for: p)

            if p.isPlaying {
                // Keep active time fresh as long as player is playing
                playerPlaybackActiveTimes[p.key] = now
                sourcePlaybackActiveTimes[src] = now

                if !wasPlaying || playerPlaybackStartTimes[p.key] == nil {
                    // Newly started playing!
                    playerPlaybackStartTimes[p.key] = now
                    sourcePlaybackStartTimes[src] = now
                }
            }
            previousPlayingStates[p.key] = p.isPlaying
        }

        // 2. Select the player according to user rule: "yang terakhir saya play"
        let playingPlayers = validPlayers.filter { $0.isPlaying }
        let chosen: RemoteMediaState

        if !playingPlayers.isEmpty {
            // If one or more are playing, pick the one that started playing most recently
            chosen = playingPlayers.max { a, b in
                let timeA = lastPlaybackStartTime(for: a)
                let timeB = lastPlaybackStartTime(for: b)
                if timeA != timeB {
                    return timeA < timeB
                }
                // Tiebreaker: stick with current source if valid
                if classifySource(for: a) == self.lastActiveSource {
                    return false
                }
                if classifySource(for: b) == self.lastActiveSource {
                    return true
                }
                return false
            } ?? playingPlayers[0]
        } else {
            // If all players are paused, pick the one that was played most recently
            chosen = validPlayers.max { a, b in
                let timeA = lastPlaybackActiveTime(for: a)
                let timeB = lastPlaybackActiveTime(for: b)
                if timeA != timeB {
                    return timeA < timeB
                }
                // Tiebreaker: stick with current source if valid
                if classifySource(for: a) == self.lastActiveSource {
                    return false
                }
                if classifySource(for: b) == self.lastActiveSource {
                    return true
                }
                return false
            } ?? validPlayers[0]
        }

        applyChosenSidecarPlayer(chosen)
    }

    private func classifySource(for state: RemoteMediaState) -> PlayerSource {
        let combined = "\(state.bundleIdentifier) \(state.parentBundleIdentifier) \(state.displayName) \(state.album) \(state.title)".lowercased()
        if combined.contains("spotify") {
            return .spotify
        } else if combined.contains("com.apple.music") || state.displayName.lowercased() == "music" {
            return .appleMusic
        } else if combined.contains("vidio") {
            return .vidio
        } else if combined.contains("youtube") {
            return .youtube
        } else if combined.contains("bein") {
            return .bein
        } else {
            return .browser
        }
    }

    private func applyChosenSidecarPlayer(_ state: RemoteMediaState) {
        MediaRemoteBridge.shared.activeTargetKey = state.key
        let source = classifySource(for: state)

        var cleanTitle = state.title
        for suffix in [" - YouTube", " - Vidio", " | Vidio"] {
            if cleanTitle.hasSuffix(suffix) {
                cleanTitle = String(cleanTitle.dropLast(suffix.count))
            }
        }
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty {
            cleanTitle = source.rawValue
        }

        let cleanArtist: String
        if !state.artist.isEmpty {
            cleanArtist = state.artist
        } else if !state.album.isEmpty {
            cleanArtist = state.album
        } else {
            cleanArtist = source.rawValue
        }

        let isToggleLocked = Date().timeIntervalSince(self.lastUserToggleTime) < 1.0
        let seekElapsed = Date().timeIntervalSince(self.lastManualSeekTime)
        let isSeekLocked = seekElapsed < 1.0

        // Preserve currentTrack.isPlaying during manual toggle or manual seek/skip buffering window
        let effectivePlaying = (isToggleLocked || isSeekLocked) ? self.currentTrack.isPlaying : state.isPlaying
        let effectivePosition = isSeekLocked
            ? (self.manualSeekTargetPosition + (effectivePlaying ? max(0, seekElapsed) : 0))
            : state.position
        let effectiveDuration = state.duration > 0 ? state.duration : (self.currentTrack.title == cleanTitle ? self.currentTrack.duration : 0)

        let track = TrackInfo(
            title: cleanTitle,
            artist: cleanArtist,
            album: state.album,
            duration: effectiveDuration,
            position: effectivePosition,
            isPlaying: effectivePlaying,
            artworkURL: nil,
            source: source
        )

        let metadataChanged = (self.currentTrack.title != cleanTitle) ||
                              (self.currentTrack.artist != cleanArtist) ||
                              (self.currentTrack.isPlaying != effectivePlaying) ||
                              (self.currentTrack.source != source)

        self.currentTrack = track
        self.lastActiveSource = source

        // Continuously synchronize lyrics in background on every playback tick (prevents stuck lyrics when collapsed)
        if LyricsService.shared.hasLyrics && effectiveDuration > 0 {
            LyricsService.shared.updatePosition(effectivePosition, isPlaying: effectivePlaying)
        }

        // Resolve platform logo dynamically via API + app bundle
        let pageDomain: String = {
            switch source {
            case .youtube: return "youtube.com"
            case .vidio: return "vidio.com"
            case .spotify: return "spotify.com"
            case .appleMusic: return "music.apple.com"
            case .bein: return "beinsports.com"
            default: return ""
            }
        }()

        MediaArtworkService.shared.resolveSourceLogo(
            source: source,
            bundleId: state.bundleIdentifier,
            parentBundleId: state.parentBundleIdentifier,
            displayName: state.displayName,
            albumName: state.album,
            pageDomain: pageDomain
        ) { [weak self] logo in
            guard let self = self, self.currentTrack.source == source else { return }
            self.sourceLogoImage = logo
        }

        // Resolve real video thumbnail / song cover from sidecar's 600x600 artwork file
        let artKey = "\(source.rawValue)|\(cleanTitle)|\(cleanArtist)|\(state.artworkPath)"
        if self.lastArtworkKey != artKey || self.artworkImage == nil {
            self.lastArtworkKey = artKey
            self.lastLoadedArtworkPath = state.artworkPath

            if !state.artworkPath.isEmpty,
               let data = try? Data(contentsOf: URL(fileURLWithPath: state.artworkPath)),
               let img = NSImage(data: data) {
                self.artworkImage = img
            } else {
                self.artworkImage = nil
                MediaArtworkService.shared.resolveTrackArtwork(
                    title: cleanTitle,
                    artist: cleanArtist,
                    source: source
                ) { [weak self] fetched in
                    guard let self = self, self.currentTrack.title == cleanTitle else { return }
                    self.artworkImage = fetched
                }
            }
        }

        if metadataChanged {
            WindowManager.shared.updateCompactWidth()
        }

        if (source == .spotify || source == .appleMusic) && track.duration > 0 {
            LyricsService.shared.fetchLyrics(for: track)
        } else {
            LyricsService.shared.clearLyrics()
        }
    }

    public func refreshNowPlaying() {
        handleSidecarPlayersUpdate(MediaRemoteBridge.shared.getLatestPlayers())
    }

    public func refreshFromMediaRemote() {
        handleSidecarPlayersUpdate(MediaRemoteBridge.shared.getLatestPlayers())
    }

    // MARK: - Playback Controls (Multi-Layer Resilient Transport Controls)
    public func togglePlayPause() {
        lastManualSeekTime = .distantPast
        lastUserToggleTime = Date()
        let willPlay = !currentTrack.isPlaying
        currentTrack.isPlaying = willPlay

        let now = Date()
        let targetKey = MediaRemoteBridge.shared.activeTargetKey
        if !targetKey.isEmpty {
            playerPlaybackActiveTimes[targetKey] = now
            if willPlay {
                playerPlaybackStartTimes[targetKey] = now
            }
        }
        sourcePlaybackActiveTimes[currentTrack.source] = now
        if willPlay {
            sourcePlaybackStartTimes[currentTrack.source] = now
        }

        // Direct AppleScript for Spotify (strictly isolated to Spotify)
        if currentTrack.source == .spotify {
            DispatchQueue.global(qos: .userInitiated).async {
                let script = willPlay ? "tell application \"Spotify\" to play" : "tell application \"Spotify\" to pause"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            if targetKey.lowercased().contains("spotify") {
                if willPlay {
                    MediaRemoteBridge.shared.play(targetKey: targetKey)
                } else {
                    MediaRemoteBridge.shared.pause(targetKey: targetKey)
                }
            }
        } else if currentTrack.source == .appleMusic {
            // Direct AppleScript for Apple Music (strictly isolated to Music)
            DispatchQueue.global(qos: .userInitiated).async {
                let script = willPlay ? "tell application \"Music\" to play" : "tell application \"Music\" to pause"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            if targetKey.lowercased().contains("music") {
                if willPlay {
                    MediaRemoteBridge.shared.play(targetKey: targetKey)
                } else {
                    MediaRemoteBridge.shared.pause(targetKey: targetKey)
                }
            }
        } else if MediaRemoteBridge.shared.getLatestPlayers().isEmpty {
            // Universal Virtual Media Key fallback
            SystemMediaKeyHelper.sendSystemMediaKey(16) // NX_KEYTYPE_PLAY
        } else {
            // Browser / video players (YouTube, Vidio, Chrome)
            if willPlay {
                MediaRemoteBridge.shared.play(targetKey: targetKey)
            } else {
                MediaRemoteBridge.shared.pause(targetKey: targetKey)
            }
        }

        WindowManager.shared.updateCompactWidth()
        keepCursorVisible()
    }

    public func nextTrack() {
        let now = Date()
        let targetKey = MediaRemoteBridge.shared.activeTargetKey
        if !targetKey.isEmpty {
            playerPlaybackActiveTimes[targetKey] = now
            playerPlaybackStartTimes[targetKey] = now
        }
        sourcePlaybackActiveTimes[currentTrack.source] = now
        sourcePlaybackStartTimes[currentTrack.source] = now

        if currentTrack.source == .spotify {
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "tell application \"Spotify\" to next track"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            if targetKey.lowercased().contains("spotify") {
                MediaRemoteBridge.shared.nextTrack(targetKey: targetKey)
            }
            keepCursorVisible()
            return
        } else if currentTrack.source == .appleMusic {
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "tell application \"Music\" to next track"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            if targetKey.lowercased().contains("music") {
                MediaRemoteBridge.shared.nextTrack(targetKey: targetKey)
            }
            keepCursorVisible()
            return
        }

        if currentTrack.source == .youtube {
            skipYouTube(seconds: ObeliskSettings.shared.skipIntervalSeconds)
            return
        } else if currentTrack.source == .vidio {
            skipVidio(seconds: ObeliskSettings.shared.skipIntervalSeconds)
            return
        }

        if MediaRemoteBridge.shared.getLatestPlayers().isEmpty {
            SystemMediaKeyHelper.sendSystemMediaKey(17) // NX_KEYTYPE_NEXT
        }
        MediaRemoteBridge.shared.nextTrack(targetKey: targetKey)
        keepCursorVisible()
    }

    public func previousTrack() {
        let now = Date()
        let targetKey = MediaRemoteBridge.shared.activeTargetKey
        if !targetKey.isEmpty {
            playerPlaybackActiveTimes[targetKey] = now
            playerPlaybackStartTimes[targetKey] = now
        }
        sourcePlaybackActiveTimes[currentTrack.source] = now
        sourcePlaybackStartTimes[currentTrack.source] = now

        if currentTrack.source == .spotify {
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "tell application \"Spotify\" to previous track"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            if targetKey.lowercased().contains("spotify") {
                MediaRemoteBridge.shared.previousTrack(targetKey: targetKey)
            }
            keepCursorVisible()
            return
        } else if currentTrack.source == .appleMusic {
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "tell application \"Music\" to previous track"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            if targetKey.lowercased().contains("music") {
                MediaRemoteBridge.shared.previousTrack(targetKey: targetKey)
            }
            keepCursorVisible()
            return
        }

        if currentTrack.source == .youtube {
            skipYouTube(seconds: -ObeliskSettings.shared.skipIntervalSeconds)
            return
        } else if currentTrack.source == .vidio {
            skipVidio(seconds: -ObeliskSettings.shared.skipIntervalSeconds)
            return
        }

        if MediaRemoteBridge.shared.getLatestPlayers().isEmpty {
            SystemMediaKeyHelper.sendSystemMediaKey(18) // NX_KEYTYPE_PREVIOUS
        }
        MediaRemoteBridge.shared.previousTrack(targetKey: targetKey)
        keepCursorVisible()
    }

    public func seek(to seconds: Double) {
        let clamped: Double
        if currentTrack.duration > 0 {
            clamped = max(0, min(seconds, currentTrack.duration))
        } else {
            clamped = max(0, seconds)
        }

        currentTrack.position = clamped
        manualSeekTargetPosition = clamped
        lastManualSeekTime = Date()
        LyricsService.shared.updatePosition(clamped, isPlaying: currentTrack.isPlaying, forceSnap: true)

        let targetKey = MediaRemoteBridge.shared.activeTargetKey
        MediaRemoteBridge.shared.setElapsedTime(clamped, targetKey: targetKey)

        // Direct instant seeking fallback for Spotify and Apple Music
        if currentTrack.source == .spotify {
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "tell application \"Spotify\" to set player position to \(clamped)"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
        } else if currentTrack.source == .appleMusic {
            DispatchQueue.global(qos: .userInitiated).async {
                let script = "tell application \"Music\" to set player position to \(clamped)"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
        }

        keepCursorVisible()
    }

    public func skipYouTube(seconds: Int) {
        lastManualSeekTime = Date()
        let newPos: Double
        if seconds > 0 {
            if currentTrack.duration > 0 {
                newPos = min(currentTrack.duration, currentTrack.position + Double(seconds))
            } else {
                newPos = currentTrack.position + Double(seconds)
            }
        } else {
            newPos = max(0, currentTrack.position + Double(seconds))
        }
        currentTrack.position = newPos
        manualSeekTargetPosition = newPos

        let targetKey = MediaRemoteBridge.shared.activeTargetKey
        MediaRemoteBridge.shared.setElapsedTime(newPos, targetKey: targetKey)
        keepCursorVisible()
    }

    public func skipVidio(seconds: Int) {
        lastManualSeekTime = Date()
        let newPos: Double
        if seconds > 0 {
            if currentTrack.duration > 0 {
                newPos = min(currentTrack.duration, currentTrack.position + Double(seconds))
            } else {
                newPos = currentTrack.position + Double(seconds)
            }
        } else {
            newPos = max(0, currentTrack.position + Double(seconds))
        }
        currentTrack.position = newPos
        manualSeekTargetPosition = newPos

        // Use Command 24 (SeekToPlaybackPosition) because SkipForward/Backward (17/18) is unsupported in web browsers
        let targetKey = MediaRemoteBridge.shared.activeTargetKey
        MediaRemoteBridge.shared.setElapsedTime(newPos, targetKey: targetKey)
        keepCursorVisible()
    }

    // MARK: - Fallback Browser Tab Inspector (Only if a site doesn't register with MediaRemote)
    @discardableResult
    private func checkBrowserTabMedia() -> Bool {
        guard MediaRemoteBridge.shared.getLatestPlayers().isEmpty else { return false }
        return false
    }
}

// MARK: - Dynamic Album Artwork Color Extractor

extension NSImage {
    public func dominantAccentColor() -> Color? {
        guard let tiff = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        let width = min(32, bitmap.pixelsWide)
        let height = min(32, bitmap.pixelsHigh)
        guard width > 0, height > 0 else { return nil }

        var bestColor: Color? = nil
        var highestScore: CGFloat = -1

        let stepX = max(1, bitmap.pixelsWide / width)
        let stepY = max(1, bitmap.pixelsHigh / height)

        for y in stride(from: 0, to: bitmap.pixelsHigh, by: stepY) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: stepX) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let r = color.redComponent
                let g = color.greenComponent
                let b = color.blueComponent
                let a = color.alphaComponent
                guard a > 0.6 else { continue }

                let maxVal = max(r, max(g, b))
                let minVal = min(r, min(g, b))
                let delta = maxVal - minVal
                let saturation = maxVal > 0 ? delta / maxVal : 0
                let brightness = maxVal

                guard brightness > 0.22 && brightness < 0.95 else { continue }
                guard saturation > 0.22 else { continue }

                let score = saturation * 2.0 + brightness * 0.8
                if score > highestScore {
                    highestScore = score
                    bestColor = Color(red: Double(r), green: Double(g), blue: Double(b))
                }
            }
        }

        return bestColor
    }
}

// MARK: - Universal macOS Virtual Media Key Dispatcher

public enum SystemMediaKeyHelper: Sendable {
    public static func sendSystemMediaKey(_ key: Int32) {
        func doKey(_ down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            if let cgEv = ev?.cgEvent {
                cgEv.post(tap: .cghidEventTap)
            }
        }
        doKey(true)
        doKey(false)
    }
}
