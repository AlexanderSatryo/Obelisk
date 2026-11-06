import Foundation
import AppKit

@MainActor
public final class MediaArtworkService {
    public static let shared = MediaArtworkService()

    private var artworkCache: [String: NSImage] = [:]
    private var logoCache: [String: NSImage] = [:]
    private var inFlightArtworkKeys: Set<String> = []
    private var inFlightLogoKeys: Set<String> = []

    private init() {
        prewarmCommonPlatformLogos()
    }

    private func prewarmCommonPlatformLogos() {
        let common: [(PlayerSource, String)] = [
            (.youtube, "youtube.com"),
            (.vidio, "vidio.com"),
            (.spotify, "spotify.com"),
            (.appleMusic, "music.apple.com")
        ]
        for (src, dom) in common {
            resolveSourceLogo(source: src, pageDomain: dom) { _ in }
        }
    }

    // MARK: - Dynamic Platform / Source Logo Resolution (API + Active Process Icon)
    public func resolveSourceLogo(
        source: PlayerSource,
        bundleId: String = "",
        parentBundleId: String = "",
        displayName: String = "",
        albumName: String = "",
        pageDomain: String = "",
        completion: @escaping @MainActor @Sendable (NSImage?) -> Void
    ) {
        let domain = detectDomain(
            source: source,
            bundleId: bundleId,
            parentBundleId: parentBundleId,
            displayName: displayName,
            albumName: albumName,
            pageDomain: pageDomain
        )

        let cacheKey = !domain.isEmpty ? "domain:\(domain)" : "app:\(parentBundleId)|\(bundleId)|\(displayName)|\(source.rawValue)"

        if let cached = logoCache[cacheKey] {
            completion(cached)
            return
        }

        let appIcon = resolveInstalledAppIcon(
            source: source,
            bundleId: bundleId,
            parentBundleId: parentBundleId,
            displayName: displayName
        )

        // Immediately provide appIcon if available while API logo loads
        if let appIcon = appIcon {
            completion(appIcon)
        }

        if !domain.isEmpty {
            guard !inFlightLogoKeys.contains(cacheKey) else { return }
            inFlightLogoKeys.insert(cacheKey)

            let urlString = "https://www.google.com/s2/favicons?domain=\(domain)&sz=128"
            guard let url = URL(string: urlString) else {
                inFlightLogoKeys.remove(cacheKey)
                return
            }

            URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
                let httpResp = response as? HTTPURLResponse
                let validData = (httpResp?.statusCode == 200) ? data : nil
                Task { @MainActor in
                    guard let self = self else { return }
                    self.inFlightLogoKeys.remove(cacheKey)
                    if let validData = validData, let img = NSImage(data: validData), img.size.width >= 16 {
                        self.logoCache[cacheKey] = img
                        completion(img)
                    } else if let appIcon = appIcon {
                        self.logoCache[cacheKey] = appIcon
                        completion(appIcon)
                    }
                }
            }.resume()
        } else if let appIcon = appIcon {
            logoCache[cacheKey] = appIcon
            completion(appIcon)
        }
    }

    private func detectDomain(
        source: PlayerSource,
        bundleId: String,
        parentBundleId: String,
        displayName: String,
        albumName: String,
        pageDomain: String
    ) -> String {
        let cleanPage = pageDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanPage.isEmpty && cleanPage.contains(".") {
            return cleanPage
        }

        let combined = "\(displayName) \(albumName) \(bundleId) \(parentBundleId) \(source.rawValue)".lowercased()

        if combined.contains("vidio") { return "vidio.com" }
        if combined.contains("youtube") { return "youtube.com" }
        if combined.contains("spotify") { return "spotify.com" }
        if combined.contains("apple music") || bundleId == "com.apple.Music" || displayName.lowercased() == "music" {
            return "music.apple.com"
        }
        if combined.contains("netflix") { return "netflix.com" }
        if combined.contains("bein") { return "beinsports.com" }
        if combined.contains("soundcloud") { return "soundcloud.com" }
        if combined.contains("twitch") { return "twitch.tv" }
        if combined.contains("disney") { return "disneyplus.com" }
        if combined.contains("primevideo") || combined.contains("prime video") { return "primevideo.com" }
        if combined.contains("bilibili") || combined.contains("bstation") { return "bilibili.tv" }
        if combined.contains("tiktok") { return "tiktok.com" }

        return ""
    }

    private func resolveInstalledAppIcon(
        source: PlayerSource,
        bundleId: String,
        parentBundleId: String,
        displayName: String
    ) -> NSImage? {
        let running = NSWorkspace.shared.runningApplications

        if !parentBundleId.isEmpty {
            if let app = running.first(where: { $0.bundleIdentifier == parentBundleId }), let icon = app.icon {
                return icon
            }
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: parentBundleId) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }

        if !bundleId.isEmpty && !bundleId.lowercased().contains("webkit") {
            if let app = running.first(where: { $0.bundleIdentifier == bundleId }), let icon = app.icon {
                return icon
            }
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }

        let targetName = !displayName.isEmpty ? displayName : source.rawValue
        if !targetName.isEmpty && targetName != "None" && targetName != "Browser" {
            if let app = running.first(where: {
                ($0.localizedName ?? "").localizedCaseInsensitiveCompare(targetName) == .orderedSame
            }), let icon = app.icon {
                return icon
            }
        }

        return nil
    }

    // MARK: - Dynamic Media Thumbnail / Cover Art Fetching
    public func resolveTrackArtwork(
        title: String,
        artist: String,
        source: PlayerSource,
        artworkFilePath: String = "",
        directArtworkURL: String? = nil,
        completion: @escaping @MainActor @Sendable (NSImage?) -> Void
    ) {
        // 1. Load directly from the MediaRemote sidecar's high-resolution artwork file if available
        if !artworkFilePath.isEmpty,
           FileManager.default.fileExists(atPath: artworkFilePath),
           let img = NSImage(contentsOfFile: artworkFilePath) {
            completion(img)
            return
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty && cleanTitle != "No Media Playing" else {
            completion(nil)
            return
        }

        let cacheKey = "\(source.rawValue)|\(cleanTitle)|\(artist)|\(directArtworkURL ?? "")"
        if let cached = artworkCache[cacheKey] {
            completion(cached)
            return
        }

        // 2. If a direct thumbnail URL was extracted from the active browser/video DOM, download it
        if let urlStr = directArtworkURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
            guard !inFlightArtworkKeys.contains(cacheKey) else { return }
            inFlightArtworkKeys.insert(cacheKey)

            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.inFlightArtworkKeys.remove(cacheKey)
                    if let data = data, let img = NSImage(data: data) {
                        self.artworkCache[cacheKey] = img
                        completion(img)
                    } else {
                        completion(nil)
                    }
                }
            }.resume()
            return
        }

        // 3. Only query iTunes Music Search API for music tracks (.spotify / .appleMusic),
        // NEVER for video platforms (.youtube / .vidio) where iTunes would return unrelated song covers!
        guard source == .spotify || source == .appleMusic else {
            completion(nil)
            return
        }

        guard !inFlightArtworkKeys.contains(cacheKey) else { return }
        inFlightArtworkKeys.insert(cacheKey)

        fetchMusicArtworkFromSearchAPI(
            cacheKey: cacheKey,
            title: cleanTitle,
            artist: artist,
            completion: completion
        )
    }

    private func fetchMusicArtworkFromSearchAPI(
        cacheKey: String,
        title: String,
        artist: String,
        completion: @escaping @MainActor @Sendable (NSImage?) -> Void
    ) {
        let query = artist.isEmpty ? title : "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=music&limit=1") else {
            inFlightArtworkKeys.remove(cacheKey)
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artUrl100 = first["artworkUrl100"] as? String else {
                Task { @MainActor in
                    self?.inFlightArtworkKeys.remove(cacheKey)
                    completion(nil)
                }
                return
            }

            let hiResUrlStr = artUrl100.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            guard let artUrl = URL(string: hiResUrlStr) else {
                Task { @MainActor in
                    self?.inFlightArtworkKeys.remove(cacheKey)
                    completion(nil)
                }
                return
            }

            URLSession.shared.dataTask(with: artUrl) { [weak self] imgData, _, _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.inFlightArtworkKeys.remove(cacheKey)
                    if let imgData = imgData, let image = NSImage(data: imgData) {
                        self.artworkCache[cacheKey] = image
                        completion(image)
                    } else {
                        completion(nil)
                    }
                }
            }.resume()
        }.resume()
    }
}
