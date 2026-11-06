import SwiftUI

/// Renders the body of one expanded notch page (Media, Weather, Calendar, or File).
/// Shared by the live `ExpandedNotchView` and the Settings preview so both always show the same layout.
public struct NotchPageView: View {
    public let tab: ObeliskTab

    @ObservedObject var mediaManager: MediaManager = .shared
    @ObservedObject var lyricsService: LyricsService = .shared
    @ObservedObject var weatherService: WeatherService = .shared
    @ObservedObject var calendarService: CalendarService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared

    public init(tab: ObeliskTab) {
        self.tab = tab
    }

    public var body: some View {
        switch tab {
        case .media:
            mediaPage
        case .weather:
            DetailedWeatherView(weatherService: weatherService)
        case .calendar:
            CalendarAgendaView(calendarService: calendarService)
        case .file:
            FileTrayView()
        }
    }

    private var isVideoSource: Bool {
        mediaManager.currentTrack.source == .youtube || mediaManager.currentTrack.source == .vidio
    }

    private var shouldDisplayLyrics: Bool {
        settings.showLyricsInNotch && !isVideoSource && mediaManager.currentTrack.source != .none
    }

    /// Video, film, and non-lyrics mode show the player alone.
    /// When lyrics mode is active, the notch preserves the split columns consistently across track transitions.
    @ViewBuilder
    private var mediaPage: some View {
        if shouldDisplayLyrics {
            HStack(alignment: .top, spacing: 0) {
                MediaPlayerView(mediaManager: mediaManager)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 96)
                    .padding(.horizontal, 10)

                LyricsSideView(lyricsService: lyricsService, mediaManager: mediaManager)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 114)
            .padding(.top, 2)
        } else {
            MediaPlayerView(mediaManager: mediaManager)
                .frame(maxWidth: .infinity)
                .frame(height: 114)
                .padding(.top, 2)
        }
    }
}

