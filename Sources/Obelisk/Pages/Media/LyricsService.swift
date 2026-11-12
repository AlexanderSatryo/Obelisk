import Foundation
import Combine

@MainActor
public final class LyricsService: ObservableObject {
    public static let shared = LyricsService()

    @Published public var lines: [LyricLine] = []
    @Published public var activeLineIndex: Int = 0
    @Published public var currentLineText: String = ""
    @Published public var nextLineText: String = ""
    @Published public var isLoading: Bool = false
    public var isLyricsExpanded: Bool {
        get { ObeliskSettings.shared.showLyricsInNotch }
        set { ObeliskSettings.shared.showLyricsInNotch = newValue }
    }
    @Published public var hasLyrics: Bool = false {
        didSet {
            if hasLyrics != oldValue {
                WindowManager.shared.updateHeightForCurrentTab()
            }
        }
    }

    private var currentTrackKey: String = ""
    private var syncTimer: Timer?
    private var basePosition: Double = 0
    private var lastSyncDate: Date = Date()
    private var isCurrentlyPlaying: Bool = false
    /// Set once a lookup for `currentTrackKey` finished without a result, so we do not hammer LRCLIB every tick.
    private var settledWithoutLyrics: Bool = false
    private var lastNetworkFailure: Date = .distantPast
    private var lastAttempt: Date = .distantPast

    /// Dynamic lead-in offset in seconds to match the spring scroll transition right on the vocal attack
    public var lyricLeadInOffset: Double {
        Double(ObeliskSettings.shared.lyricsSyncOffsetMs) / 1000.0
    }

    private init() {}

    // MARK: - Fetch Lyrics
    public func fetchLyrics(for track: TrackInfo) {
        guard !track.title.isEmpty, track.title != "No Media Playing" else {
            clearLyrics()
            return
        }

        let trackKey = "\(track.artist.lowercased()) - \(track.title.lowercased())"
        if trackKey == currentTrackKey {
            if !lines.isEmpty || isLoading { return }
            // Not found: stay quiet. Network failure: retry no more often than every 15 seconds.
            if settledWithoutLyrics { return }
            if Date().timeIntervalSince(lastNetworkFailure) < 15 { return }
        }

        currentTrackKey = trackKey
        isLoading = true
        hasLyrics = false
        settledWithoutLyrics = false
        lastAttempt = Date()

        Task { [weak self] in
            let outcome = await LyricsService.fetchFromLRCLIB(
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration
            )
            let lyricsData = outcome.data

            guard let self = self, self.currentTrackKey == trackKey else { return }
            self.isLoading = false
            if lyricsData.lines.isEmpty {
                if outcome.networkFailed {
                    self.lastNetworkFailure = Date()
                } else {
                    self.settledWithoutLyrics = true
                }
            }
            self.lines = lyricsData.lines
            self.hasLyrics = !lyricsData.lines.isEmpty

            if self.hasLyrics {
                if ObeliskSettings.shared.autoExpandLyrics {
                    ObeliskSettings.shared.showLyricsInNotch = true
                    WindowManager.shared.updateHeightForCurrentTab()
                }
                let liveTrack = MediaManager.shared.currentTrack
                let livePos = (liveTrack.title == track.title) ? liveTrack.position : track.position
                let livePlaying = (liveTrack.title == track.title) ? liveTrack.isPlaying : track.isPlaying
                self.updatePosition(livePos, isPlaying: livePlaying, forceSnap: true)
            } else {
                if ObeliskSettings.shared.autoExpandLyrics {
                    ObeliskSettings.shared.showLyricsInNotch = false
                    WindowManager.shared.updateHeightForCurrentTab()
                }
                self.currentLineText = "Lyrics not available"
                self.nextLineText = ""
            }
        }
    }

    public func clearLyricsIfNeeded() {
        guard !currentTrackKey.isEmpty || hasLyrics || !lines.isEmpty || isLoading else { return }
        clearLyrics()
    }

    public func clearLyrics() {
        stopInterpolationTimer()
        settledWithoutLyrics = false
        lastNetworkFailure = .distantPast
        currentTrackKey = ""
        lines = []
        activeLineIndex = 0
        currentLineText = ""
        nextLineText = ""
        hasLyrics = false
        isLoading = false
        if ObeliskSettings.shared.autoExpandLyrics {
            ObeliskSettings.shared.showLyricsInNotch = false
            WindowManager.shared.updateHeightForCurrentTab()
        }
    }

    // MARK: - Symmetric Phase-Locked Position Sync & 30Hz Sub-Second Interpolation

    /// Updates base playback position using symmetric phase-locked correction against the player's true audio clock
    public func updatePosition(_ position: Double, isPlaying: Bool = true, forceSnap: Bool = false) {
        let now = Date()

        if forceSnap || !isPlaying || !self.isCurrentlyPlaying {
            self.basePosition = position
            self.lastSyncDate = now
            self.isCurrentlyPlaying = isPlaying
            evaluateLinePosition(position)
        } else {
            let elapsed = now.timeIntervalSince(self.lastSyncDate)
            let currentEstimate = self.basePosition + elapsed
            let drift = position - currentEstimate

            if abs(drift) > 0.18 {
                // Immediate snap on seek, skip, or large clock jump
                self.basePosition = position
                self.lastSyncDate = now
                evaluateLinePosition(position)
            } else {
                // Symmetric Phase-Locked Loop (PLL): converges both positive and negative drift smoothly without ratcheting
                let corrected = currentEstimate + (drift * 0.65)
                self.basePosition = corrected
                self.lastSyncDate = now
                evaluateLinePosition(corrected)
            }
        }

        if isPlaying && syncTimer == nil {
            startInterpolationTimer()
        } else if !isPlaying {
            stopInterpolationTimer()
        }
    }

    private func startInterpolationTimer() {
        syncTimer?.invalidate()
        let t = Timer(timeInterval: 0.033, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickInterpolation()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        syncTimer = t
    }

    private func stopInterpolationTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    private func tickInterpolation() {
        guard isCurrentlyPlaying, !lines.isEmpty else { return }
        let elapsed = Date().timeIntervalSince(lastSyncDate)
        let estimatedPos = basePosition + elapsed
        evaluateLinePosition(estimatedPos)
    }

    private func evaluateLinePosition(_ position: Double) {
        guard !lines.isEmpty else { return }

        let syncPos = position + lyricLeadInOffset

        // Find the active line index: highest index where line.time <= syncPos (or 0 during intro)
        var foundIndex = 0
        if syncPos >= lines[0].time {
            for (i, line) in lines.enumerated() {
                if line.time <= syncPos {
                    foundIndex = i
                } else {
                    break
                }
            }
        }

        let newCurrentText = lines[foundIndex].text
        let newNextText = (foundIndex + 1 < lines.count) ? lines[foundIndex + 1].text : ""

        if foundIndex != activeLineIndex || currentLineText != newCurrentText || nextLineText != newNextText {
            activeLineIndex = foundIndex
            currentLineText = newCurrentText
            nextLineText = newNextText
        }
    }

    // MARK: - LRCLIB API Request & Unified Candidate Pool Scoring
    private static func cleanedTitle(_ title: String) -> String {
        var t = title
        for pattern in ["\\s*\\(.*?\\)", "\\s*\\[.*?\\]", "\\s+-\\s+(Remaster(ed)?|Live|Single|Radio Edit|Mono|Stereo|Version|Deluxe).*$", "\\s+feat\\..*$", "\\s+ft\\..*$"] {
            t = t.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fetchJSON(_ urlString: String, timeout: TimeInterval) async -> (json: Any?, failed: Bool) {
        guard let url = URL(string: urlString) else { return (nil, false) }
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Obelisk-macOS/1.1.1 (https://github.com/AlexanderSatryo/Obelisk)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return (nil, true) }
            if http.statusCode == 200 {
                return (try? JSONSerialization.jsonObject(with: data), false)
            }
            // 404 means "no such track"; anything else (429, 5xx) is transient.
            return (nil, http.statusCode != 404)
        } catch {
            return (nil, true)
        }
    }

    // MARK: - LRCLIB API Request & Unified Candidate Pool Scoring
    private static func fetchFromLRCLIB(title: String, artist: String, album: String, duration: Double) async -> (data: LyricsData, networkFailed: Bool) {
        func enc(_ s: String) -> String {
            s.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? s
        }

        var candidates: [[String: Any]] = []
        var failures = 0
        var requests = 0

        // 1. Query /api/search to gather all available versions
        let search = await fetchJSON("https://lrclib.net/api/search?q=\(enc(artist + " " + title))", timeout: 8)
        requests += 1
        if search.failed { failures += 1 }
        if let array = search.json as? [[String: Any]] { candidates.append(contentsOf: array) }

        // 2. Exact lookup with album + duration
        let durationParam = duration > 0 ? "&duration=\(Int(duration.rounded()))" : ""
        let albumParam = album.isEmpty ? "" : "&album_name=\(enc(album))"
        let exact = await fetchJSON(
            "https://lrclib.net/api/get?track_name=\(enc(title))&artist_name=\(enc(artist))\(albumParam)\(durationParam)",
            timeout: 6
        )
        requests += 1
        if exact.failed { failures += 1 }
        if let json = exact.json as? [String: Any] { candidates.append(json) }

        // 3. Nothing found: retry with a cleaned title ("Song (Remastered 2011)" -> "Song")
        let simple = cleanedTitle(title)
        if candidates.isEmpty, !simple.isEmpty, simple.lowercased() != title.lowercased() {
            let retry = await fetchJSON("https://lrclib.net/api/search?q=\(enc(artist + " " + simple))", timeout: 8)
            requests += 1
            if retry.failed { failures += 1 }
            if let array = retry.json as? [[String: Any]] { candidates.append(contentsOf: array) }
        }

        let result = selectBestCandidate(
            from: candidates,
            targetTitle: title,
            targetArtist: artist,
            targetAlbum: album,
            targetDuration: duration
        )
        return (result, result.lines.isEmpty && failures > 0 && failures == requests)
    }

    private static func selectBestCandidate(
        from candidates: [[String: Any]],
        targetTitle: String,
        targetArtist: String,
        targetAlbum: String,
        targetDuration: Double
    ) -> LyricsData {
        guard !candidates.isEmpty else { return .empty }

        let cleanTargetAlbum = targetAlbum.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTargetTitle = targetTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTargetArtist = targetArtist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var bestItem: [String: Any]?
        var bestScore: Double = -Double.infinity

        for item in candidates {
            let synced = (item["syncedLyrics"] as? String) ?? ""
            let plain = (item["plainLyrics"] as? String) ?? ""
            guard !synced.isEmpty || !plain.isEmpty else { continue }

            var score: Double = 0

            // 1. Strongly require synced LRC lyrics over plain unsynced lyrics
            if !synced.isEmpty {
                score += 1000.0
            }

            // 2. High-precision duration proximity scoring against Spotify / Apple Music exact duration
            let candDuration = (item["duration"] as? NSNumber)?.doubleValue ?? (item["duration"] as? Double ?? 0)
            if targetDuration > 0 && candDuration > 0 {
                let diff = abs(candDuration - targetDuration)
                if diff <= 0.35 {
                    score += 500.0
                } else if diff <= 0.85 {
                    score += 340.0
                } else if diff <= 1.25 {
                    score += 180.0
                }
                score -= diff * 120.0

                // Fractional millisecond duration in LRCLIB indicates a direct streaming platform sync
                if abs(candDuration - candDuration.rounded()) > 0.001 {
                    score += 85.0
                }
            }

            // 3. Title & Artist match
            if let candTitle = (item["trackName"] as? String)?.lowercased() {
                if candTitle == cleanTargetTitle {
                    score += 90.0
                } else if candTitle.contains(cleanTargetTitle) || cleanTargetTitle.contains(candTitle) {
                    score += 45.0
                }
            }

            if let candArtist = (item["artistName"] as? String)?.lowercased() {
                if candArtist == cleanTargetArtist || candArtist.contains(cleanTargetArtist) {
                    score += 70.0
                }
            }

            // 4. Album match bonus (weighted below duration accuracy so wrong-length rips never win)
            if !cleanTargetAlbum.isEmpty,
               let candAlbum = (item["albumName"] as? String)?.lowercased() {
                if candAlbum == cleanTargetAlbum {
                    score += 65.0
                } else if candAlbum.contains(cleanTargetAlbum) || cleanTargetAlbum.contains(candAlbum) {
                    score += 35.0
                }
            }

            if score > bestScore {
                bestScore = score
                bestItem = item
            }
        }

        guard let chosen = bestItem else { return .empty }

        if let synced = chosen["syncedLyrics"] as? String, !synced.isEmpty {
            let parsedLines = parseLRC(synced)
            if !parsedLines.isEmpty {
                return LyricsData(lines: parsedLines, isSynced: true, rawLrc: synced)
            }
        }

        if let plain = chosen["plainLyrics"] as? String, !plain.isEmpty {
            let parsedLines = parsePlain(plain)
            return LyricsData(lines: parsedLines, isSynced: false, rawLrc: nil)
        }

        return .empty
    }

    // MARK: - LRC Parser
    private static func parseLRC(_ lrc: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") else { continue }

            guard let closeBracketIndex = trimmed.firstIndex(of: "]") else { continue }
            let timeString = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracketIndex])
            let lyricText = String(trimmed[trimmed.index(after: closeBracketIndex)...]).trimmingCharacters(in: .whitespaces)

            let timeParts = timeString.components(separatedBy: ":")
            if timeParts.count == 2,
               let minutes = Double(timeParts[0].replacingOccurrences(of: ",", with: ".")),
               let seconds = Double(timeParts[1].replacingOccurrences(of: ",", with: ".")) {
                let totalSeconds = (minutes * 60.0) + seconds
                if !lyricText.isEmpty {
                    result.append(LyricLine(time: totalSeconds, text: lyricText))
                }
            }
        }

        return result.sorted { $0.time < $1.time }
    }

    private static func parsePlain(_ plain: String) -> [LyricLine] {
        let rawLines = plain.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return rawLines.enumerated().map { index, text in
            LyricLine(time: Double(index * 4), text: text)
        }
    }
}

private extension CharacterSet {
    /// Like `.urlQueryAllowed` but also escapes `&`, `+`, `=` and `?` so titles such as "Rock & Roll" stay intact.
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&+=?#")
        return set
    }()
}
