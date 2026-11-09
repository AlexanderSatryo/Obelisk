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
    private var preferredSourceOverride: PlayerSource? = nil
    private var cachedSpotifyImage: NSImage?
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
            self.cachedSpotifyImage = nil
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

        if name.contains("vidio") || bundle.contains("vidio") {
            preferredSourceOverride = .vidio
            handleSidecarPlayersUpdate(MediaRemoteBridge.shared.getLatestPlayers())
        } else if name.contains("youtube") || bundle.contains("youtube") {
            preferredSourceOverride = .youtube
            handleSidecarPlayersUpdate(MediaRemoteBridge.shared.getLatestPlayers())
        } else if bundle == "com.spotify.client" {
            preferredSourceOverride = .spotify
            handleSidecarPlayersUpdate(MediaRemoteBridge.shared.getLatestPlayers())
        } else if bundle == "com.apple.music" {
            preferredSourceOverride = .appleMusic
            handleSidecarPlayersUpdate(MediaRemoteBridge.shared.getLatestPlayers())
        } else if bundle == "com.google.chrome" || bundle == "com.apple.safari" {
            preferredSourceOverride = nil
            if !checkBrowserTabMedia() {
                handleSidecarPlayersUpdate(MediaRemoteBridge.shared.getLatestPlayers())
            }
        }
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

        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontName = (frontApp?.localizedName ?? "").lowercased()
        let frontBundle = (frontApp?.bundleIdentifier ?? "").lowercased()

        var targetSource: PlayerSource? = preferredSourceOverride
        if frontName.contains("vidio") || frontBundle.contains("vidio") {
            targetSource = .vidio
            preferredSourceOverride = .vidio
        } else if frontName.contains("youtube") || frontBundle.contains("youtube") {
            targetSource = .youtube
            preferredSourceOverride = .youtube
        } else if frontBundle == "com.spotify.client" {
            targetSource = .spotify
            preferredSourceOverride = .spotify
        } else if frontBundle == "com.apple.music" {
            targetSource = .appleMusic
            preferredSourceOverride = .appleMusic
        }

        // Score all live players to select the active one
        var bestPlayer: RemoteMediaState?
        var bestScore: Int = Int.min

        for p in validPlayers {
            let src = classifySource(for: p)
            var score = 0

            // 1. Actively playing media gets high priority
            if p.isPlaying {
                score += 350
            }

            // 2. Match frontmost or user-focused media app
            if let target = targetSource, src == target {
                score += 500
            }

            // 3. Match previously active source for continuity
            if src == lastActiveSource {
                score += 120
            }

            // 4. Valid duration & metadata bonus
            if p.duration > 0 {
                score += 40
            }
            if !p.artworkPath.isEmpty {
                score += 20
            }

            if score > bestScore {
                bestScore = score
                bestPlayer = p
            }
        }

        guard let chosen = bestPlayer else { return }
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
        if !state.artworkPath.isEmpty,
           (self.lastLoadedArtworkPath != state.artworkPath || self.artworkImage == nil),
           let img = NSImage(contentsOfFile: state.artworkPath) {
            self.artworkImage = img
            self.lastLoadedArtworkPath = state.artworkPath
            self.lastArtworkKey = artKey
            if source == .spotify {
                self.cachedSpotifyImage = img
            }
        } else if state.artworkPath.isEmpty && self.lastArtworkKey != artKey {
            self.lastArtworkKey = artKey
            self.lastLoadedArtworkPath = ""
            self.artworkImage = nil
            MediaArtworkService.shared.resolveTrackArtwork(
                title: cleanTitle,
                artist: cleanArtist,
                source: source
            ) { [weak self] fetched in
                guard let self = self, self.currentTrack.title == cleanTitle else { return }
                if let fetched = fetched {
                    self.artworkImage = fetched
                } else if source == .spotify, let cached = self.cachedSpotifyImage {
                    self.artworkImage = cached
                }
            }
        }

        WindowManager.shared.updateCompactWidth()

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

    // MARK: - Playback Controls (Explicit Play / Pause & Native Background Seeking)
    public func togglePlayPause() {
        lastManualSeekTime = .distantPast
        lastUserToggleTime = Date()
        let willPlay = !currentTrack.isPlaying
        currentTrack.isPlaying = willPlay

        let targetKey = MediaRemoteBridge.shared.activeTargetKey
        if willPlay {
            // Explicitly send PLAY (0) so it never gets inverted
            MediaRemoteBridge.shared.play(targetKey: targetKey)
        } else {
            // Explicitly send PAUSE (1) so it never gets inverted
            MediaRemoteBridge.shared.pause(targetKey: targetKey)
        }

        WindowManager.shared.updateCompactWidth()
        keepCursorVisible()
    }

    public func nextTrack() {
        if currentTrack.source == .youtube {
            skipYouTube(seconds: 15)
            return
        } else if currentTrack.source == .vidio {
            skipVidio(seconds: 15)
            return
        }
        MediaRemoteBridge.shared.nextTrack()
        keepCursorVisible()
    }

    public func previousTrack() {
        if currentTrack.source == .youtube {
            skipYouTube(seconds: -15)
            return
        } else if currentTrack.source == .vidio {
            skipVidio(seconds: -15)
            return
        }
        MediaRemoteBridge.shared.previousTrack()
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

        MediaRemoteBridge.shared.setElapsedTime(clamped)

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

        // Direct MediaRemote SeekToPlaybackPosition (24) on YouTube's MRNowPlayingController
        MediaRemoteBridge.shared.setElapsedTime(newPos)
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

        if seconds > 0 {
            MediaRemoteBridge.shared.skipForward15()
        } else {
            MediaRemoteBridge.shared.skipBackward15()
        }
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
