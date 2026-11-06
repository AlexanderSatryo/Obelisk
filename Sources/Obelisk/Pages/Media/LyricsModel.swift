import Foundation

public struct LyricLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let time: Double
    public let text: String

    public init(id: UUID = UUID(), time: Double, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

public struct LyricsData: Equatable, Sendable {
    public var lines: [LyricLine]
    public var isSynced: Bool
    public var rawLrc: String?

    public static let empty = LyricsData(lines: [], isSynced: false, rawLrc: nil)
}

