import Foundation

public enum PlayerSource: String, Sendable, CaseIterable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case youtube = "YouTube"
    case vidio = "Vidio"
    case bein = "beIN SPORTS"
    case browser = "Browser"
    case none = "None"
}

public struct TrackInfo: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: Double       // total duration in seconds
    public var position: Double       // current position in seconds
    public var isPlaying: Bool
    public var artworkURL: String?
    public var source: PlayerSource

    public init(
        title: String,
        artist: String,
        album: String,
        duration: Double,
        position: Double,
        isPlaying: Bool,
        artworkURL: String? = nil,
        source: PlayerSource = .none
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
        self.artworkURL = artworkURL
        self.source = source
    }

    public static let empty = TrackInfo(
        title: "No Media Playing",
        artist: "Play audio in Spotify or Music",
        album: "",
        duration: 0,
        position: 0,
        isPlaying: false,
        artworkURL: nil,
        source: .none
    )

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1.0)
    }

    public var formattedPosition: String {
        formatSeconds(position)
    }

    public var formattedDuration: String {
        formatSeconds(duration)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        } else {
            return String(format: "%d:%02d", minutes, remainder)
        }
    }
}

