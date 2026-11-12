import SwiftUI
import AppKit

/// Navigation categories displayed in the preferences sidebar.
public enum SettingsCategory: String, CaseIterable, Identifiable, Sendable {
    case appearance = "Appearance"
    case behavior = "Behavior"
    case modules = "Modules"
    case media = "Media & Lyrics"
    case weather = "Weather"
    case system = "System"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .appearance: return "paintbrush.fill"
        case .behavior: return "hand.tap.fill"
        case .modules: return "square.grid.2x2.fill"
        case .media: return "music.note"
        case .weather: return "cloud.sun.fill"
        case .system: return "gearshape.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .appearance: return "Surface material, geometry, colors, and compact wings."
        case .behavior: return "Hover timing, animation curves, and trackpad gestures."
        case .modules: return "Enabled dashboard tabs and default opening view."
        case .media: return "Synced lyrics typography, playback, and seek controls."
        case .weather: return "Measurement units, geolocation, and refresh frequency."
        case .system: return "Startup behavior, menu bar icon, and application lifecycle."
        }
    }

    /// Refined soft pastel badges inspired by macOS System Settings
    public var badgeGradient: LinearGradient {
        switch self {
        case .appearance:
            return LinearGradient(
                colors: [Color(red: 0.38, green: 0.45, blue: 0.60), Color(red: 0.28, green: 0.34, blue: 0.48)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .behavior:
            return LinearGradient(
                colors: [Color(red: 0.32, green: 0.52, blue: 0.54), Color(red: 0.24, green: 0.40, blue: 0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .modules:
            return LinearGradient(
                colors: [Color(red: 0.35, green: 0.52, blue: 0.44), Color(red: 0.25, green: 0.40, blue: 0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .media:
            return LinearGradient(
                colors: [Color(red: 0.58, green: 0.38, blue: 0.44), Color(red: 0.44, green: 0.26, blue: 0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .weather:
            return LinearGradient(
                colors: [Color(red: 0.58, green: 0.48, blue: 0.34), Color(red: 0.44, green: 0.36, blue: 0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .system:
            return LinearGradient(
                colors: [Color(red: 0.44, green: 0.44, blue: 0.52), Color(red: 0.32, green: 0.32, blue: 0.40)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Sub-category tabs within the Appearance settings page to cleanly separate Compact and Expanded notch options.
public enum AppearanceSubMode: String, CaseIterable, Identifiable, Sendable {
    case compact = "Compact"
    case expanded = "Expanded"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .compact: return "capsule"
        case .expanded: return "macwindow"
        }
    }
}

/// Structured search index item strictly matching English UI text (sections, rows, subtitles, and options)
public struct SettingsSearchItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let category: SettingsCategory
    public let keywords: [String]

    public func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }
        let tokens = trimmed.split(separator: " ").map { String($0) }.filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return false }

        // Fast direct substring match
        if title.lowercased().contains(trimmed) || category.rawValue.lowercased().contains(trimmed) || keywords.contains(where: { $0.lowercased().contains(trimmed) }) {
            return true
        }

        // Multi-word query: all tokens must match either title, category, or UI keywords
        let corpus = ([title, category.rawValue] + keywords).joined(separator: " ").lowercased()
        return tokens.allSatisfy { token in corpus.contains(token) }
    }
}

/// Comprehensive deep index of all settings options across Obelisk matching English UI names only
public enum SettingsSearchIndex {
    public static let allItems: [SettingsSearchItem] = [
        // 1. Appearance
        SettingsSearchItem(
            id: "surface",
            title: "Surface Material",
            category: .appearance,
            keywords: ["surface & border", "compact surface", "expanded surface", "compact", "expanded", "surface", "material", "standby material", "expanded material", "liquid glass", "dark liquid glass", "dark glass", "frosted glass", "pitch black", "ambient glow", "apple glass", "oled"]
        ),
        SettingsSearchItem(
            id: "opacity",
            title: "Notch Opacity",
            category: .appearance,
            keywords: ["surface & border", "notch opacity", "opacity", "transparency", "surface opacity", "alpha"]
        ),
        SettingsSearchItem(
            id: "border",
            title: "Hairline Rim Border",
            category: .appearance,
            keywords: ["surface & border", "hairline rim border", "border width", "border opacity", "border", "edge stroke", "outline", "rim", "curvature"]
        ),
        SettingsSearchItem(
            id: "theme",
            title: "Color Theme & Brightness",
            category: .appearance,
            keywords: ["color theme & brightness", "color preset", "brightness", "color theme", "theme", "palette", "soft pastel", "colorful", "monochrome", "standard"]
        ),
        SettingsSearchItem(
            id: "geometry",
            title: "Geometry & Dimensions",
            category: .appearance,
            keywords: ["geometry", "compact width offset", "compact height offset", "expanded width preset", "expanded width", "expanded height offset", "dimensions", "width", "height", "offset", "preset", "compact", "standard", "wide", "custom"]
        ),
        SettingsSearchItem(
            id: "topCornerRadius",
            title: "Top Bezel Corner Radius",
            category: .appearance,
            keywords: ["geometry", "compact top radius (bezel)", "expanded top radius (bezel)", "top radius", "top corner radius", "bezel", "curvature"]
        ),
        SettingsSearchItem(
            id: "bottomCornerRadius",
            title: "Bottom Corner Radius",
            category: .appearance,
            keywords: ["geometry", "compact bottom radius", "expanded bottom radius", "bottom radius", "bottom corner radius", "corner radius", "curvature"]
        ),
        SettingsSearchItem(
            id: "standbyHUD",
            title: "Standby HUD & Notifications",
            category: .appearance,
            keywords: ["standby hud & notifications", "standby hud layout", "standby hud", "hud", "show caps lock hud", "caps lock", "battery fully charged alert", "battery", "side expansion (wings)", "horizontal wings", "downward card", "volume", "brightness"]
        ),
        SettingsSearchItem(
            id: "compactWings",
            title: "Compact Wings Mode",
            category: .appearance,
            keywords: ["compact wings", "wing expansion mode", "always minimal", "dynamic auto", "always wide", "wings"]
        ),
        SettingsSearchItem(
            id: "leftWing",
            title: "Left Wing Content",
            category: .appearance,
            keywords: ["compact wings", "left wing content", "left wing", "weather mini", "battery status", "clock", "camera", "logo", "album artwork", "thumbnail"]
        ),
        SettingsSearchItem(
            id: "rightWing",
            title: "Right Wing Style",
            category: .appearance,
            keywords: ["compact wings", "right wing style", "right wing", "waveform", "visualizer", "equalizer", "battery", "telemetry", "timer", "minimal dots"]
        ),
        SettingsSearchItem(
            id: "waveformColor",
            title: "Waveform Color",
            category: .appearance,
            keywords: ["compact wings", "waveform color", "waveform", "audio wave", "media accent", "monochrome white"]
        ),
        SettingsSearchItem(
            id: "timerColor",
            title: "Compact Timer Color",
            category: .appearance,
            keywords: ["compact wings", "compact timer color", "timer color", "timer", "playback timer", "timer accent"]
        ),

        // 2. Behavior
        SettingsSearchItem(
            id: "trigger",
            title: "Interaction & Hover",
            category: .behavior,
            keywords: ["interaction & hover", "trigger mode", "hover dwell latency", "exit grace period", "hover", "click only", "dwell", "latency"]
        ),
        SettingsSearchItem(
            id: "animation",
            title: "Animation Speed",
            category: .behavior,
            keywords: ["animation", "speed preset", "animation speed", "snappy", "balanced", "fluid", "spring", "damping"]
        ),
        SettingsSearchItem(
            id: "gestures",
            title: "Trackpad Gestures",
            category: .behavior,
            keywords: ["trackpad gestures", "two-finger page swipe", "invert horizontal swipe", "gestures", "trackpad", "swipe"]
        ),
        SettingsSearchItem(
            id: "volumeHUD",
            title: "Replace System Volume & Brightness HUD",
            category: .behavior,
            keywords: ["system overlays & hud", "replace system volume & brightness hud", "volume hud", "brightness hud", "osd", "suppress", "satryo's buds", "floating notification", "headphones", "audio device"]
        ),

        // 3. Modules
        SettingsSearchItem(
            id: "mediaModule",
            title: "Media Player",
            category: .modules,
            keywords: ["dashboard pages", "media player", "music", "playback controls", "artwork", "scrubber", "now playing"]
        ),
        SettingsSearchItem(
            id: "weatherModule",
            title: "Weather Forecast",
            category: .modules,
            keywords: ["dashboard pages", "weather", "forecast", "current conditions", "temperature", "hourly forecast"]
        ),
        SettingsSearchItem(
            id: "calendarModule",
            title: "Calendar Agenda",
            category: .modules,
            keywords: ["dashboard pages", "calendar", "agenda", "events", "upcoming events", "schedule"]
        ),
        SettingsSearchItem(
            id: "fileModule",
            title: "File & AirDrop Shelf",
            category: .modules,
            keywords: ["dashboard pages", "file & airdrop shelf", "file", "airdrop", "shelf", "drag and drop", "tray"]
        ),
        SettingsSearchItem(
            id: "defaultOpeningTab",
            title: "Default View",
            category: .modules,
            keywords: ["default view", "opening tab", "initial notch tab", "remember last used"]
        ),
        SettingsSearchItem(
            id: "fileTrayCapacity",
            title: "Shelf Capacity",
            category: .modules,
            keywords: ["file & airdrop shelf", "shelf capacity", "maximum files in shelf", "file limit"]
        ),
        SettingsSearchItem(
            id: "autoClearAfterAirDrop",
            title: "Auto-Clear After AirDrop",
            category: .modules,
            keywords: ["file & airdrop shelf", "auto-clear after airdrop", "clear staged files", "empty shelf"]
        ),
        SettingsSearchItem(
            id: "calendarEventDots",
            title: "Calendar Event Indicators",
            category: .modules,
            keywords: ["calendar strip", "show event indicators", "event indicators", "event dots", "markers"]
        ),
        SettingsSearchItem(
            id: "scheduledAlerts",
            title: "Scheduled Alerts & Alarms",
            category: .modules,
            keywords: ["scheduled alerts & alarms", "scheduled alerts tab", "standby alert duration", "require ok to dismiss", "alarms", "reminders", "alert", "ok"]
        ),
        SettingsSearchItem(
            id: "downloads",
            title: "Downloads & Tasks",
            category: .modules,
            keywords: ["downloads & tasks", "live download & task progress", "live downloads", "download", "task progress", "percentage", "crdownload"]
        ),
        SettingsSearchItem(
            id: "notifications",
            title: "Dynamic Island Notifications",
            category: .modules,
            keywords: ["dynamic island notifications", "incoming notification popups (standby hud)", "notification category", "auto-dismiss timeout", "notification history page", "notification", "notifications", "alerts", "touch id"]
        ),

        // 4. Media & Lyrics
        SettingsSearchItem(
            id: "lyrics",
            title: "Synchronized Lyrics",
            category: .media,
            keywords: ["lyrics", "show synchronized lyrics", "auto-expand on track change", "live lyrics", "karaoke"]
        ),
        SettingsSearchItem(
            id: "lyricsScale",
            title: "Typography Scale",
            category: .media,
            keywords: ["lyrics", "typography scale", "lyrics font scale", "text size", "font size"]
        ),
        SettingsSearchItem(
            id: "lyricsOffset",
            title: "Lyrics Timing Offset",
            category: .media,
            keywords: ["lyrics", "lyrics timing offset", "timing offset", "delay", "sync lead"]
        ),
        SettingsSearchItem(
            id: "seekInterval",
            title: "Video Seek Interval",
            category: .media,
            keywords: ["navigation", "video seek interval", "seek step duration", "rewind", "fast-forward", "scrub"]
        ),

        // 5. Weather
        SettingsSearchItem(
            id: "temperatureUnit",
            title: "Temperature Unit",
            category: .weather,
            keywords: ["units", "temperature", "celsius", "fahrenheit", "degrees"]
        ),
        SettingsSearchItem(
            id: "windUnit",
            title: "Wind Velocity Unit",
            category: .weather,
            keywords: ["units", "wind velocity", "wind speed", "km/h", "mph", "m/s"]
        ),
        SettingsSearchItem(
            id: "weatherLocation",
            title: "Location Mode & City",
            category: .weather,
            keywords: ["location & refresh", "location mode", "city name", "gps (automatic)", "manual city"]
        ),
        SettingsSearchItem(
            id: "weatherRefresh",
            title: "Weather Refresh Interval",
            category: .weather,
            keywords: ["location & refresh", "refresh interval", "polling frequency", "update rate"]
        ),

        // 6. System
        SettingsSearchItem(
            id: "login",
            title: "Launch at Login",
            category: .system,
            keywords: ["integration", "launch at login", "start at login", "startup", "login items"]
        ),
        SettingsSearchItem(
            id: "menuBar",
            title: "Show Menu Bar Icon",
            category: .system,
            keywords: ["integration", "show menu bar icon", "status bar icon", "status item", "menu bar"]
        ),
        SettingsSearchItem(
            id: "resetAll",
            title: "Reset All Preferences",
            category: .system,
            keywords: ["management", "reset all preferences", "reset defaults", "restore factory defaults", "reset"]
        ),
        SettingsSearchItem(
            id: "quit",
            title: "Quit Obelisk",
            category: .system,
            keywords: ["management", "quit obelisk", "quit", "exit", "terminate", "close"]
        )
    ]
}

/// Fully redesigned macOS System Settings-style Preferences window for Obelisk.
/// Built with native inset grouped cards, modern component styling, live interactive preview,
/// deep search filtering across all wings & options, and complete state persistence.
public struct SettingsView: View {
    @ObservedObject var settings: ObeliskSettings = .shared
    @ObservedObject var windowManager: WindowManager = .shared
    @ObservedObject var mediaManager: MediaManager = .shared
    @ObservedObject var weatherService: WeatherService = .shared

    @State private var draft: ObeliskSettingsDraft = ObeliskSettings.shared.makeDraft()
    @State private var savedSnapshot: ObeliskSettingsDraft = ObeliskSettings.shared.makeDraft()
    @State private var selectedCategory: SettingsCategory = .appearance
    @State private var selectedCategoryFilter: SettingsCategory? = nil
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var previewExpandedState: Bool = false
    @State private var appearanceSubMode: AppearanceSubMode = .compact
    @State private var previewTab: ObeliskTab = .media
    @State private var showSavedMessage: Bool = false
    @State private var isPreviewFrozen: Bool = false
    @State private var frozenDraft: ObeliskSettingsDraft? = nil
    @State private var hasUnsavedChanges: Bool = false
    @State private var showingResetConfirmation: Bool = false

    private var availableDefaultOpeningTabOptions: [(value: DefaultOpeningTab, title: String)] {
        var options: [(value: DefaultOpeningTab, title: String)] = [(.lastUsed, DefaultOpeningTab.lastUsed.title)]
        if draft.enableMediaTab { options.append((.alwaysMedia, DefaultOpeningTab.alwaysMedia.title)) }
        if draft.enableWeatherTab { options.append((.alwaysWeather, DefaultOpeningTab.alwaysWeather.title)) }
        if draft.enableCalendarTab { options.append((.alwaysCalendar, DefaultOpeningTab.alwaysCalendar.title)) }
        if draft.enableFileTab { options.append((.alwaysFile, DefaultOpeningTab.alwaysFile.title)) }
        if draft.enableAlertTab { options.append((.alwaysAlert, DefaultOpeningTab.alwaysAlert.title)) }
        if draft.enableNotificationTab { options.append((.alwaysNotification, DefaultOpeningTab.alwaysNotification.title)) }
        return options
    }

    private func matchesCurrentQuery(_ searchItemId: String) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return false }
        guard let item = SettingsSearchIndex.allItems.first(where: { $0.id == searchItemId }) else { return false }
        return item.matches(query: q)
    }

    private func matchingItemCount(for category: SettingsCategory) -> Int {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return 0 }
        return SettingsSearchIndex.allItems.filter { $0.category == category && $0.matches(query: q) }.count
    }

    private var totalMatchingItems: Int {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return 0 }
        return SettingsSearchIndex.allItems.filter { $0.matches(query: q) }.count
    }

    private func isSectionVisible(_ searchItemIds: [String]) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return searchItemIds.contains { matchesCurrentQuery($0) }
    }

    private var filteredCategories: [SettingsCategory] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return SettingsCategory.allCases }
        return SettingsCategory.allCases.filter { cat in
            cat.rawValue.lowercased().contains(q) ||
            cat.subtitle.lowercased().contains(q) ||
            matchingItemCount(for: cat) > 0
        }
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left macOS System Settings Sidebar (strictly locked 236pt width)
            sidebarView
                .frame(width: 236)
                .frame(maxHeight: .infinity, alignment: .top)
                .fixedSize(horizontal: true, vertical: false)
                .background(Color(red: 22/255, green: 22/255, blue: 25/255))

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)

            // MARK: - Right Detail Content Area (strictly locked 663pt width to match 900x640 window)
            VStack(spacing: 0) {
                // macOS Category or Search Header
                if searchText.isEmpty {
                    detailHeaderView
                } else {
                    searchHeaderView
                }

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Pinned Live Preview (when in Appearance and not searching)
                if selectedCategory == .appearance && searchText.isEmpty {
                    previewCanvas
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .padding(.bottom, 12)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                }

                // Inset Grouped Scrollable Settings Form
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        if !searchText.isEmpty {
                            if totalMatchingItems == 0 {
                                noResultsAcrossAllSettingsView
                            } else {
                                allSearchResultsView
                            }
                        } else {
                            switch selectedCategory {
                            case .appearance:
                                appearanceTab
                            case .behavior:
                                behaviorTab
                            case .modules:
                                modulesTab
                            case .media:
                                mediaTab
                            case .weather:
                                weatherTab
                            case .system:
                                systemTab
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Bottom Action Footer
                detailFooterView
            }
            .frame(width: 663, height: 640, alignment: .top)
            .clipped()
            .background(Color(red: 16/255, green: 16/255, blue: 18/255))
        }
        .frame(width: 900, height: 640)
        .background(Color(red: 16/255, green: 16/255, blue: 18/255))
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Reset All Preferences?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset All to Default", role: .destructive) {
                draft = ObeliskSettingsDraft()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all appearance, behavior, modules, and media preferences to their initial factory settings.")
        }
        .onAppear {
            let initial = settings.makeDraft()
            draft = initial
            savedSnapshot = initial
            hasUnsavedChanges = false
            isSearchFocused = false
            selectedCategoryFilter = nil
        }
        .onChange(of: draft) { newDraft in
            hasUnsavedChanges = (newDraft != savedSnapshot)
        }
        .onChange(of: searchText) { _ in
            selectedCategoryFilter = nil
        }
    }

    // MARK: - Left Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Traffic Light Safe Clearance & App Title Bar
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.90))

                Text("Obelisk")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 38)
            .padding(.bottom, 12)

            // macOS System Settings Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.40))

                TextField("Search Settings", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        selectedCategoryFilter = nil
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.40))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // Navigation List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    if searchText.isEmpty {
                        ForEach(SettingsCategory.allCases) { category in
                            categorySidebarItem(
                                category: category,
                                isSelected: selectedCategory == category,
                                matchCount: nil
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    } else {
                        // "All Results" master row
                        let isAllSelected = (selectedCategoryFilter == nil)
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedCategoryFilter = nil
                            }
                        }) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                                        .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                                        )

                                    Image(systemName: "list.bullet.indent")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                Text("All Results")
                                    .font(.system(size: 13, weight: isAllSelected ? .semibold : .medium))
                                    .foregroundColor(isAllSelected ? .white : .white.opacity(0.80))

                                Spacer()

                                Text("\(totalMatchingItems)")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(isAllSelected ? Color.blue : Color.white.opacity(0.15))
                                    )

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(isAllSelected ? .white.opacity(0.50) : .white.opacity(0.18))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isAllSelected ? Color.white.opacity(0.13) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.vertical, 4)

                        let matchingCats = SettingsCategory.allCases.filter { matchingItemCount(for: $0) > 0 }
                        if matchingCats.isEmpty {
                            Text("No matching categories")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(.top, 12)
                        } else {
                            ForEach(matchingCats) { category in
                                let isSelected = (selectedCategoryFilter == category)
                                categorySidebarItem(
                                    category: category,
                                    isSelected: isSelected,
                                    matchCount: matchingItemCount(for: category)
                                ) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        selectedCategoryFilter = category
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func categorySidebarItem(
        category: SettingsCategory,
        isSelected: Bool,
        matchCount: Int? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Rounded square soft badge
                ZStack {
                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                        .fill(category.badgeGradient)
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )

                    Image(systemName: category.icon)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))

                Spacer()

                if let count = matchCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.18))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.50) : .white.opacity(0.18))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.13) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Header

    private var detailHeaderView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedCategory.rawValue)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Text(selectedCategory.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    draft.resetCategoryToDefaults(selectedCategory)
                }
            }) {
                Text("Reset to Defaults")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.60))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset \(selectedCategory.rawValue) to Defaults")
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    // MARK: - Detail Footer

    private var detailFooterView: some View {
        HStack(spacing: 12) {
            if showSavedMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.20, green: 0.78, blue: 0.45))
                        .font(.system(size: 11))
                    Text("Changes saved to notch")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.90))
                }
            } else if hasUnsavedChanges {
                Text("Unsaved changes")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.60))
            } else {
                Text("All settings in sync with notch")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.50))
            }

            Spacer()

            if hasUnsavedChanges {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        draft = savedSnapshot
                        hasUnsavedChanges = false
                    }
                }) {
                    Text("Discard")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                saveSettings()
            }) {
                Text("Save Changes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .fill(Color.blue.opacity(hasUnsavedChanges ? 0.92 : 0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .stroke(Color.blue.opacity(hasUnsavedChanges ? 0.35 : 0.08), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!hasUnsavedChanges && !showSavedMessage)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(red: 18/255, green: 18/255, blue: 21/255))
    }

    private func saveSettings() {
        settings.apply(draft: draft)
        savedSnapshot = settings.makeDraft()
        hasUnsavedChanges = false
        withAnimation(.easeInOut(duration: 0.2)) {
            showSavedMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSavedMessage = false
            }
        }
    }

    // MARK: - Search Views & Results Across All Settings

    private var searchHeaderView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.blue)

                    Text(selectedCategoryFilter != nil ? "\(selectedCategoryFilter!.rawValue) Results" : "Search Results")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }

                let currentMatches = selectedCategoryFilter != nil ? matchingItemCount(for: selectedCategoryFilter!) : totalMatchingItems
                Text("\(currentMatches) setting\(currentMatches == 1 ? "" : "s") matching \"\(searchText)\"\(selectedCategoryFilter != nil ? " in \(selectedCategoryFilter!.rawValue)" : " across all categories")")
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            if selectedCategoryFilter != nil {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedCategoryFilter = nil
                    }
                }) {
                    Text("Show All Categories")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }

            Button(action: {
                searchText = ""
                selectedCategoryFilter = nil
                isSearchFocused = false
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Clear Search")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.80))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    private var noResultsAcrossAllSettingsView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 56, height: 56)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.top, 40)

            Text("No Settings Found")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Text("No settings match \"\(searchText)\". Try searching for keywords like download, notch, speed, battery, weather, or notifications.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.50))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button(action: {
                searchText = ""
                selectedCategoryFilter = nil
                isSearchFocused = false
            }) {
                Text("Clear Search")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var allSearchResultsView: some View {
        let displayCategories: [SettingsCategory] = {
            if let filter = selectedCategoryFilter {
                return matchingItemCount(for: filter) > 0 ? [filter] : []
            }
            return SettingsCategory.allCases.filter { matchingItemCount(for: $0) > 0 }
        }()

        return VStack(alignment: .leading, spacing: 26) {
            ForEach(displayCategories) { category in
                VStack(alignment: .leading, spacing: 14) {
                    // Category Header Banner
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(category.badgeGradient)
                                .frame(width: 22, height: 22)
                            Image(systemName: category.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Text(category.rawValue.uppercased())
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.90))
                            .tracking(0.6)

                        Spacer()

                        let count = matchingItemCount(for: category)
                        Text("\(count) match\(count == 1 ? "" : "es")")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.blue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                    }
                    .padding(.horizontal, 2)

                    // Render Category Tab Sections
                    switch category {
                    case .appearance:
                        appearanceTab
                    case .behavior:
                        behaviorTab
                    case .modules:
                        modulesTab
                    case .media:
                        mediaTab
                    case .weather:
                        weatherTab
                    case .system:
                        systemTab
                    }

                    if category != displayCategories.last {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.top, 12)
                    }
                }
            }
        }
    }

    // MARK: - 1. Appearance Tab

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            if searchText.isEmpty {
                switch appearanceSubMode {
                case .compact:
                    compactAppearanceSections
                case .expanded:
                    expandedAppearanceSections
                }
            } else {
                // When actively searching, display both Compact and Expanded sections so all query matches are shown
                compactAppearanceSections
                expandedAppearanceSections
            }
        }
    }

    // MARK: - Compact Appearance Sections

    private var compactAppearanceSections: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Surface & Border (Compact Standby)
            if isSectionVisible(["surface", "opacity", "border"]) {
                PreferenceSection(
                    title: "COMPACT SURFACE & BORDER",
                    isHighlighted: matchesCurrentQuery("surface") || matchesCurrentQuery("opacity") || matchesCurrentQuery("border")
                ) {
                    PreferenceRow(
                        title: "Standby Material",
                        subtitle: draft.compactSurfaceStyle.subtitle,
                        isHighlighted: matchesCurrentQuery("surface")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.compactSurfaceStyle,
                            options: NotchSurfaceStyle.allCases.map { ($0, $0.title) }
                        )
                    }

                    if draft.compactSurfaceStyle.isLiquidGlass {
                        PreferenceSliderRow(
                            title: "Glass Blur Density",
                            subtitle: "Adjusts background optical blur and frosted dispersion",
                            isHighlighted: matchesCurrentQuery("blur"),
                            value: $draft.compactGlassBlur,
                            range: 0.10...1.00
                        )
                    }

                    PreferenceSliderRow(
                        title: "Standby Opacity",
                        subtitle: "Adjusts translucency and body darkness of the standby notch",
                        isHighlighted: matchesCurrentQuery("opacity"),
                        value: $draft.compactOpacity,
                        range: 0.15...1.00
                    )

                    PreferenceToggleRow(
                        title: "Hairline Rim Border",
                        subtitle: "Draws a crisp edge stroke along the bottom curvature",
                        isHighlighted: matchesCurrentQuery("border"),
                        isOn: $draft.showBorder
                    )

                    if draft.showBorder {
                        PreferenceSliderRow(
                            title: "Border Width",
                            isHighlighted: matchesCurrentQuery("border"),
                            value: $draft.borderWidth,
                            range: 0.5...2.0
                        )

                        PreferenceSliderRow(
                            title: "Border Opacity",
                            subtitle: "Adjusts outline stroke opacity around notch edge (useful if faint on external monitors)",
                            isHighlighted: matchesCurrentQuery("border"),
                            value: $draft.borderOpacity,
                            range: 0.04...0.40
                        )
                    }
                }
            }

            // Compact Geometry & Dimensions
            if isSectionVisible(["geometry", "topCornerRadius", "bottomCornerRadius"]) {
                PreferenceSection(
                    title: "COMPACT GEOMETRY",
                    isHighlighted: matchesCurrentQuery("geometry") || matchesCurrentQuery("topCornerRadius") || matchesCurrentQuery("bottomCornerRadius")
                ) {
                    PreferenceSliderRow(
                        title: "Compact Width Offset",
                        subtitle: "Horizontal width clearance for the compact standby notch (40 - 380 pt)",
                        isHighlighted: matchesCurrentQuery("geometry"),
                        value: $draft.compactWidthOffset,
                        range: 40...380
                    )

                    PreferenceSliderRow(
                        title: "Compact Height Offset",
                        subtitle: "Vertical height adjustment relative to camera bezel (-4 to +24 pt)",
                        isHighlighted: matchesCurrentQuery("geometry"),
                        value: $draft.compactHeightOffset,
                        range: -4...24
                    )

                    PreferenceSliderRow(
                        title: "Compact Top Radius (Bezel)",
                        subtitle: "Curvature at the top corners meeting the display bezel (0 - 16 pt)",
                        isHighlighted: matchesCurrentQuery("topCornerRadius"),
                        value: $draft.compactTopCornerRadius,
                        range: 0...16
                    )

                    PreferenceSliderRow(
                        title: "Compact Bottom Radius",
                        subtitle: "Curvature at the bottom corners of the standby notch (8 - 18 pt)",
                        isHighlighted: matchesCurrentQuery("bottomCornerRadius") || matchesCurrentQuery("geometry"),
                        value: $draft.compactCornerRadius,
                        range: 8...18
                    )
                }
            }

            // Compact Wings & Telemetry
            if isSectionVisible(["compactWings", "leftWing", "rightWing", "waveformColor", "timerColor"]) {
                PreferenceSection(
                    title: "COMPACT WINGS",
                    isHighlighted: matchesCurrentQuery("compactWings") || matchesCurrentQuery("leftWing") || matchesCurrentQuery("rightWing") || matchesCurrentQuery("waveformColor") || matchesCurrentQuery("timerColor")
                ) {
                    PreferenceRow(
                        title: "Wing Expansion Mode",
                        subtitle: "When the notch widens beyond the hardware housing",
                        isHighlighted: matchesCurrentQuery("compactWings")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.compactWingMode,
                            options: CompactWingMode.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceRow(
                        title: "Left Wing Content",
                        subtitle: "Element on the left of the collapsed camera notch",
                        isHighlighted: matchesCurrentQuery("leftWing")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.leftWingContent,
                            options: LeftWingContentMode.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceRow(
                        title: "Right Wing Style",
                        subtitle: "Visualizer or telemetry on the right wing",
                        isHighlighted: matchesCurrentQuery("rightWing")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.rightWingStyle,
                            options: RightWingStyle.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceRow(
                        title: "Waveform Color",
                        subtitle: "Media platform accent or clean monochrome",
                        isHighlighted: matchesCurrentQuery("waveformColor")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.waveformColorMode,
                            options: WaveformColorMode.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceRow(
                        title: "Compact Timer Color",
                        subtitle: "Color applied to playback timer",
                        isHighlighted: matchesCurrentQuery("timerColor")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.compactTimerColorMode,
                            options: CompactTimerColorMode.allCases.map { ($0, $0.title) }
                        )
                    }
                }
            }

            // Standby HUD Notifications
            if isSectionVisible(["standbyHUD"]) {
                PreferenceSection(
                    title: "STANDBY HUD & NOTIFICATIONS",
                    isHighlighted: matchesCurrentQuery("standbyHUD")
                ) {
                    PreferenceRow(
                        title: "Standby HUD Layout",
                        subtitle: draft.standbyHUDStyle.subtitle,
                        isHighlighted: matchesCurrentQuery("standbyHUD")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.standbyHUDStyle,
                            options: StandbyHUDStyle.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceToggleRow(
                        title: "Show Caps Lock HUD",
                        subtitle: "Briefly display Caps Lock On / Off status on the notch",
                        isHighlighted: matchesCurrentQuery("standbyHUD"),
                        isOn: $draft.showCapsLockHUD
                    )

                    PreferenceToggleRow(
                        title: "Battery Fully Charged Alert",
                        subtitle: "Notify on the notch when battery reaches 100% while connected to power",
                        isHighlighted: matchesCurrentQuery("standbyHUD"),
                        isOn: $draft.notifyBatteryFullyCharged
                    )
                }
            }

            // Color Theme & Brightness
            if isSectionVisible(["theme"]) {
                PreferenceSection(
                    title: "COLOR THEME & BRIGHTNESS",
                    isHighlighted: matchesCurrentQuery("theme")
                ) {
                    PreferenceRow(
                        title: "Color Preset",
                        subtitle: draft.colorTheme.subtitle,
                        isHighlighted: matchesCurrentQuery("theme")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.colorTheme,
                            options: NotchColorTheme.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceSliderRow(
                        title: "Brightness",
                        isHighlighted: matchesCurrentQuery("theme"),
                        value: $draft.colorBrightness,
                        range: 0.5...1.5
                    )
                }
            }
        }
    }

    // MARK: - Expanded Appearance Sections

    private var expandedAppearanceSections: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Surface & Border (Expanded Dashboard)
            if isSectionVisible(["surface", "opacity", "border"]) {
                PreferenceSection(
                    title: "EXPANDED SURFACE & BORDER",
                    isHighlighted: matchesCurrentQuery("surface") || matchesCurrentQuery("opacity") || matchesCurrentQuery("border")
                ) {
                    PreferenceRow(
                        title: "Expanded Material",
                        subtitle: draft.expandedSurfaceStyle.subtitle,
                        isHighlighted: matchesCurrentQuery("surface")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.expandedSurfaceStyle,
                            options: NotchSurfaceStyle.allCases.map { ($0, $0.title) }
                        )
                    }

                    if draft.expandedSurfaceStyle.isLiquidGlass {
                        PreferenceSliderRow(
                            title: "Glass Blur Density",
                            subtitle: "Adjusts background optical blur and frosted dispersion",
                            isHighlighted: matchesCurrentQuery("blur"),
                            value: $draft.expandedGlassBlur,
                            range: 0.10...1.00
                        )
                    }

                    PreferenceSliderRow(
                        title: "Expanded Opacity",
                        subtitle: "Adjusts translucency and body darkness of the expanded notch",
                        isHighlighted: matchesCurrentQuery("opacity"),
                        value: $draft.expandedOpacity,
                        range: 0.15...1.00
                    )

                    PreferenceToggleRow(
                        title: "Hairline Rim Border",
                        subtitle: "Draws a crisp edge stroke along the bottom curvature",
                        isHighlighted: matchesCurrentQuery("border"),
                        isOn: $draft.showBorder
                    )

                    if draft.showBorder {
                        PreferenceSliderRow(
                            title: "Border Width",
                            isHighlighted: matchesCurrentQuery("border"),
                            value: $draft.borderWidth,
                            range: 0.5...2.0
                        )

                        PreferenceSliderRow(
                            title: "Border Opacity",
                            subtitle: "Adjusts outline stroke opacity around notch edge (useful if faint on external monitors)",
                            isHighlighted: matchesCurrentQuery("border"),
                            value: $draft.borderOpacity,
                            range: 0.04...0.40
                        )
                    }
                }
            }

            // Expanded Geometry & Dimensions
            if isSectionVisible(["geometry", "topCornerRadius", "bottomCornerRadius"]) {
                PreferenceSection(
                    title: "EXPANDED GEOMETRY",
                    isHighlighted: matchesCurrentQuery("geometry") || matchesCurrentQuery("topCornerRadius") || matchesCurrentQuery("bottomCornerRadius")
                ) {
                    PreferenceRow(
                        title: "Expanded Width Preset",
                        subtitle: "Quick size profile for the expanded dashboard",
                        isHighlighted: matchesCurrentQuery("geometry")
                    ) {
                        ModernMenuPicker(
                            selection: Binding(
                                get: {
                                    if draft.expandedWidthPreset == .custom {
                                        return .custom
                                    }
                                    if abs(draft.expandedWidth - ExpandedWidthPreset.compact.width) < 1.0 {
                                        return .compact
                                    } else if abs(draft.expandedWidth - ExpandedWidthPreset.standard.width) < 1.0 {
                                        return .standard
                                    } else if abs(draft.expandedWidth - ExpandedWidthPreset.wide.width) < 1.0 {
                                        return .wide
                                    } else {
                                        return .custom
                                    }
                                },
                                set: { newPreset in
                                    draft.expandedWidthPreset = newPreset
                                    if newPreset != .custom {
                                        draft.expandedWidth = Double(newPreset.width)
                                    }
                                }
                            ),
                            options: ExpandedWidthPreset.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceSliderRow(
                        title: "Expanded Width",
                        subtitle: "Custom width in points for expanded dashboard (560 - 760 pt)",
                        isHighlighted: matchesCurrentQuery("geometry"),
                        value: Binding(
                            get: { draft.expandedWidth },
                            set: { newVal in
                                draft.expandedWidth = newVal
                                if abs(newVal - ExpandedWidthPreset.compact.width) < 1.0 {
                                    draft.expandedWidthPreset = .compact
                                } else if abs(newVal - ExpandedWidthPreset.standard.width) < 1.0 {
                                    draft.expandedWidthPreset = .standard
                                } else if abs(newVal - ExpandedWidthPreset.wide.width) < 1.0 {
                                    draft.expandedWidthPreset = .wide
                                } else {
                                    draft.expandedWidthPreset = .custom
                                }
                            }
                        ),
                        range: 560...760
                    )

                    PreferenceSliderRow(
                        title: "Expanded Height Offset",
                        subtitle: "Fine-tune vertical height of expanded cards and dashboard pages (-24 to +100 pt)",
                        isHighlighted: matchesCurrentQuery("geometry"),
                        value: $draft.expandedHeightOffset,
                        range: -24...100
                    )

                    PreferenceSliderRow(
                        title: "Expanded Top Radius (Bezel)",
                        subtitle: "Curvature at the top corners meeting the display bezel when expanded (0 - 20 pt)",
                        isHighlighted: matchesCurrentQuery("topCornerRadius"),
                        value: $draft.expandedTopCornerRadius,
                        range: 0...20
                    )

                    PreferenceSliderRow(
                        title: "Expanded Bottom Radius",
                        subtitle: "Curvature at the bottom corners of the expanded dashboard (12 - 26 pt)",
                        isHighlighted: matchesCurrentQuery("bottomCornerRadius") || matchesCurrentQuery("geometry"),
                        value: $draft.expandedCornerRadius,
                        range: 12...26
                    )
                }
            }

            // Color Theme & Brightness
            if isSectionVisible(["theme"]) {
                PreferenceSection(
                    title: "COLOR THEME & BRIGHTNESS",
                    isHighlighted: matchesCurrentQuery("theme")
                ) {
                    PreferenceRow(
                        title: "Color Preset",
                        subtitle: draft.colorTheme.subtitle,
                        isHighlighted: matchesCurrentQuery("theme")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.colorTheme,
                            options: NotchColorTheme.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceSliderRow(
                        title: "Brightness",
                        isHighlighted: matchesCurrentQuery("theme"),
                        value: $draft.colorBrightness,
                        range: 0.5...1.5
                    )
                }
            }
        }
    }

    // MARK: - 2. Behavior Tab

    private var behaviorTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            if isSectionVisible(["trigger"]) {
                PreferenceSection(
                    title: "INTERACTION & HOVER",
                    isHighlighted: matchesCurrentQuery("trigger")
                ) {
                    PreferenceRow(
                        title: "Trigger Mode",
                        subtitle: "How the notch is expanded into full dashboard",
                        isHighlighted: matchesCurrentQuery("trigger")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.triggerMode,
                            options: NotchTriggerMode.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceSliderRow(
                        title: "Hover Dwell Latency",
                        subtitle: "Delay before hover triggers expansion (lower = faster response)",
                        mode: .milliseconds,
                        isHighlighted: matchesCurrentQuery("trigger"),
                        value: $draft.hoverDwellMs,
                        range: 30...300,
                        step: 5
                    )

                    PreferenceSliderRow(
                        title: "Exit Grace Period",
                        subtitle: "Grace time notch stays open after cursor leaves (higher = prevents accidental collapse)",
                        mode: .milliseconds,
                        isHighlighted: matchesCurrentQuery("trigger"),
                        value: $draft.exitGraceMs,
                        range: 80...400,
                        step: 10
                    )
                }
            }

            if isSectionVisible(["animation"]) {
                PreferenceSection(
                    title: "ANIMATION",
                    isHighlighted: matchesCurrentQuery("animation")
                ) {
                    PreferenceRow(
                        title: "Speed Preset",
                        subtitle: "Spring stiffness and damping for morphing",
                        isHighlighted: matchesCurrentQuery("animation")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.animationSpeed,
                            options: AnimationSpeedPreset.allCases.map { ($0, $0.title) }
                        )
                    }
                }
            }

            if isSectionVisible(["gestures"]) {
                PreferenceSection(
                    title: "TRACKPAD GESTURES",
                    isHighlighted: matchesCurrentQuery("gestures")
                ) {
                    PreferenceToggleRow(
                        title: "Two-Finger Page Swipe",
                        subtitle: "Swipe horizontally to navigate between pages",
                        isHighlighted: matchesCurrentQuery("gestures"),
                        isOn: $draft.enableHorizontalSwipe
                    )

                    if draft.enableHorizontalSwipe {
                        PreferenceToggleRow(
                            title: "Invert Horizontal Swipe",
                            subtitle: "Reverse swipe navigation direction if trackpad natural scrolling feels inverted",
                            isHighlighted: matchesCurrentQuery("gestures"),
                            isOn: $draft.invertHorizontalSwipe
                        )
                    }
                }
            }

            if isSectionVisible(["volumeHUD", "replaceHUD", "osd", "trigger"]) {
                PreferenceSection(
                    title: "SYSTEM OVERLAYS & HUD",
                    isHighlighted: matchesCurrentQuery("volume") || matchesCurrentQuery("brightness") || matchesCurrentQuery("hud") || matchesCurrentQuery("osd")
                ) {
                    PreferenceToggleRow(
                        title: "Replace System Volume & Brightness HUD",
                        subtitle: "Suppresses macOS floating OSD popups and displays sleek controls in the notch instead",
                        isHighlighted: matchesCurrentQuery("volume") || matchesCurrentQuery("brightness") || matchesCurrentQuery("hud"),
                        isOn: $draft.replaceSystemVolumeHUD
                    )
                }
            }
        }
    }

    // MARK: - 3. Modules Tab

    private var modulesTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            if isSectionVisible(["mediaModule", "weatherModule", "calendarModule", "fileModule"]) {
                PreferenceSection(
                    title: "DASHBOARD PAGES",
                    isHighlighted: matchesCurrentQuery("mediaModule") || matchesCurrentQuery("weatherModule") || matchesCurrentQuery("calendarModule") || matchesCurrentQuery("fileModule")
                ) {
                    PreferenceToggleRow(
                        title: "Media Player",
                        subtitle: "Playback controls, artwork, and synchronized lyrics",
                        isHighlighted: matchesCurrentQuery("mediaModule"),
                        isOn: $draft.enableMediaTab
                    )

                    PreferenceToggleRow(
                        title: "Weather",
                        subtitle: "Current conditions and hourly forecast peek",
                        isHighlighted: matchesCurrentQuery("weatherModule"),
                        isOn: $draft.enableWeatherTab
                    )

                    PreferenceToggleRow(
                        title: "Calendar",
                        subtitle: "Upcoming events and quick link to Calendar",
                        isHighlighted: matchesCurrentQuery("calendarModule"),
                        isOn: $draft.enableCalendarTab
                    )

                    PreferenceToggleRow(
                        title: "File & AirDrop Shelf",
                        subtitle: "Quick drag-and-drop file shelf and native AirDrop sharing",
                        isHighlighted: matchesCurrentQuery("fileModule"),
                        isOn: $draft.enableFileTab
                    )

                    PreferenceToggleRow(
                        title: "Scheduled Alerts Tab (Expanded Notch)",
                        subtitle: "Dedicated dashboard tab before notifications to configure routine alarms and alerts",
                        isHighlighted: matchesCurrentQuery("alerts") || matchesCurrentQuery("modules"),
                        isOn: $draft.enableAlertTab
                    )

                    PreferenceToggleRow(
                        title: "Notification History Page (Expanded Notch)",
                        subtitle: "Dedicated dashboard tab to browse and search recent notifications",
                        isHighlighted: matchesCurrentQuery("notifications") || matchesCurrentQuery("modules"),
                        isOn: $draft.enableNotificationTab
                    )
                }
            }

            if isSectionVisible(["downloads"]) {
                PreferenceSection(
                    title: "DOWNLOADS & TASKS",
                    isHighlighted: matchesCurrentQuery("downloads")
                ) {
                    PreferenceToggleRow(
                        title: "Live Download & Task Progress",
                        subtitle: "Shows real-time download percentage and completion alerts in the notch",
                        isHighlighted: matchesCurrentQuery("downloads"),
                        isOn: $draft.showDownloadsOnStandby
                    )
                }
            }

            if isSectionVisible(["notifications"]) {
                PreferenceSection(
                    title: "DYNAMIC ISLAND NOTIFICATIONS",
                    isHighlighted: matchesCurrentQuery("notifications")
                ) {
                    PreferenceToggleRow(
                        title: "Incoming Notification Popups (Standby HUD)",
                        subtitle: "Pop up incoming alerts (WhatsApp, Telegram, Slack, etc.) while notch is collapsed",
                        isHighlighted: matchesCurrentQuery("notifications"),
                        isOn: $draft.enableNotifications
                    )

                    if draft.enableNotifications {
                        PreferenceRow(
                            title: "Notification Category",
                            subtitle: "Select which category of alerts appear in the notch",
                            isHighlighted: matchesCurrentQuery("notifications")
                        ) {
                            ModernMenuPicker(
                                selection: $draft.notificationFilterCategory,
                                options: NotificationFilterCategory.allCases.map { ($0, $0.title) },
                                width: 200
                            )
                        }

                        PreferenceSliderRow(
                            title: "Auto-Dismiss Timeout",
                            isHighlighted: matchesCurrentQuery("notifications"),
                            value: $draft.notificationAutoDismissSeconds,
                            range: 1.5...15
                        )
                    }
                }
            }

            if isSectionVisible(["defaultOpeningTab"]) {
                PreferenceSection(
                    title: "DEFAULT VIEW",
                    isHighlighted: matchesCurrentQuery("defaultOpeningTab")
                ) {
                    PreferenceRow(
                        title: "Opening Tab",
                        subtitle: "Page displayed automatically when expanding the notch",
                        isHighlighted: matchesCurrentQuery("defaultOpeningTab")
                    ) {
                        ModernMenuPicker(
                            selection: Binding<DefaultOpeningTab>(
                                get: {
                                    if availableDefaultOpeningTabOptions.contains(where: { $0.value == draft.defaultOpeningTab }) {
                                        return draft.defaultOpeningTab
                                    }
                                    return .lastUsed
                                },
                                set: { newVal in
                                    draft.defaultOpeningTab = newVal
                                }
                            ),
                            options: availableDefaultOpeningTabOptions,
                            width: 190
                        )
                    }
                }
            }

            if isSectionVisible(["fileModule", "fileTrayCapacity", "autoClearAfterAirDrop"]) {
                PreferenceSection(
                    title: "FILE & AIRDROP SHELF",
                    isHighlighted: matchesCurrentQuery("fileModule") || matchesCurrentQuery("fileTrayCapacity") || matchesCurrentQuery("autoClearAfterAirDrop")
                ) {
                    PreferenceRow(
                        title: "Shelf Capacity",
                        subtitle: "Maximum files held concurrently in the notch shelf",
                        isHighlighted: matchesCurrentQuery("fileTrayCapacity") || matchesCurrentQuery("fileModule")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.fileTrayCapacity,
                            options: [
                                (5, "5 Files"),
                                (10, "10 Files"),
                                (25, "25 Files")
                            ],
                            width: 130
                        )
                    }

                    PreferenceToggleRow(
                        title: "Auto-Clear After AirDrop",
                        subtitle: "Automatically empties staged files after sending via AirDrop",
                        isHighlighted: matchesCurrentQuery("autoClearAfterAirDrop") || matchesCurrentQuery("fileModule"),
                        isOn: $draft.autoClearAfterAirDrop
                    )
                }
            }

            if isSectionVisible(["calendarModule", "calendarEventDots"]) {
                PreferenceSection(
                    title: "CALENDAR STRIP",
                    isHighlighted: matchesCurrentQuery("calendarModule") || matchesCurrentQuery("calendarEventDots")
                ) {
                    PreferenceToggleRow(
                        title: "Show Event Indicators",
                        subtitle: "Draws subtle markers for days that hold events",
                        isHighlighted: matchesCurrentQuery("calendarEventDots") || matchesCurrentQuery("calendarModule"),
                        isOn: $draft.showCalendarEventDots
                    )
                }
            }

            if isSectionVisible(["scheduledAlerts", "alerts"]) {
                PreferenceSection(
                    title: "SCHEDULED ALERTS & ALARMS",
                    isHighlighted: matchesCurrentQuery("scheduledAlerts") || matchesCurrentQuery("alerts")
                ) {
                    PreferenceToggleRow(
                        title: "Scheduled Alerts Tab",
                        subtitle: "Dedicated dashboard tab before notifications to configure routine alarms and alerts",
                        isHighlighted: matchesCurrentQuery("scheduledAlerts") || matchesCurrentQuery("alerts"),
                        isOn: $draft.enableAlertTab
                    )

                    if draft.enableAlertTab {
                        PreferenceRow(
                            title: "Standby Alert Duration",
                            subtitle: "How long routine alerts stay visible in the notch before auto-dismissing",
                            isHighlighted: matchesCurrentQuery("scheduledAlerts") || matchesCurrentQuery("alerts")
                        ) {
                            ModernMenuPicker(
                                selection: $draft.scheduledAlertDismissMinutes,
                                options: [
                                    (1, "1 Minute"),
                                    (2, "2 Minutes"),
                                    (3, "3 Minutes"),
                                    (5, "5 Minutes"),
                                    (10, "10 Minutes"),
                                    (0, "Until Dismissed")
                                ],
                                width: 170
                            )
                        }

                        PreferenceToggleRow(
                            title: "Require OK to Dismiss",
                            subtitle: "Keep alert visible in the standby notch until you click the OK button",
                            isHighlighted: matchesCurrentQuery("scheduledAlerts") || matchesCurrentQuery("alerts"),
                            isOn: $draft.scheduledAlertRequireOK
                        )
                    }
                }
            }
        }
    }

    // MARK: - 4. Media Tab

    private var mediaTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            if isSectionVisible(["lyrics", "lyricsScale", "lyricsOffset"]) {
                PreferenceSection(
                    title: "LYRICS",
                    isHighlighted: matchesCurrentQuery("lyrics") || matchesCurrentQuery("lyricsScale") || matchesCurrentQuery("lyricsOffset")
                ) {
                    PreferenceToggleRow(
                        title: "Show Synchronized Lyrics",
                        subtitle: "Displays live lyrics below playback controls",
                        isHighlighted: matchesCurrentQuery("lyrics"),
                        isOn: $draft.showLyricsInNotch
                    )

                    if draft.showLyricsInNotch {
                        PreferenceToggleRow(
                            title: "Auto-Expand on Track Change",
                            subtitle: "Opens extended lyrics container when a new song starts",
                            isHighlighted: matchesCurrentQuery("lyrics"),
                            isOn: $draft.autoExpandLyrics
                        )

                        PreferenceRow(
                            title: "Typography Scale",
                            subtitle: "Visual size of lyrics lines in expanded dashboard",
                            isHighlighted: matchesCurrentQuery("lyricsScale")
                        ) {
                            ModernMenuPicker(
                                selection: $draft.lyricsFontSizeScale,
                                options: LyricsFontSizeScale.allCases.map { ($0, $0.title) }
                            )
                        }

                        let syncBinding = Binding<Double>(
                            get: { Double(draft.lyricsSyncOffsetMs) },
                            set: { draft.lyricsSyncOffsetMs = Int(round($0)) }
                        )
                        PreferenceSliderRow(
                            title: "Lyrics Timing Offset",
                            mode: .signedMilliseconds,
                            isHighlighted: matchesCurrentQuery("lyricsOffset"),
                            value: syncBinding,
                            range: -200...800,
                            step: 25
                        )
                    }
                }
            }

            if isSectionVisible(["seekInterval"]) {
                PreferenceSection(
                    title: "NAVIGATION",
                    isHighlighted: matchesCurrentQuery("seekInterval")
                ) {
                    PreferenceRow(
                        title: "Video Seek Interval",
                        subtitle: "Seconds skipped on rewind or fast-forward for browser video (YouTube & Vidio). Music tracks use next/prev.",
                        isHighlighted: matchesCurrentQuery("seekInterval")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.skipIntervalSeconds,
                            options: [
                                (10, "10 Seconds"),
                                (15, "15 Seconds"),
                                (30, "30 Seconds"),
                                (60, "60 Seconds")
                            ]
                        )
                    }
                }
            }
        }
    }

    // MARK: - 5. Weather Tab

    private var weatherTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            if isSectionVisible(["temperatureUnit", "windUnit"]) {
                PreferenceSection(
                    title: "UNITS",
                    isHighlighted: matchesCurrentQuery("temperatureUnit") || matchesCurrentQuery("windUnit")
                ) {
                    PreferenceRow(
                        title: "Temperature",
                        subtitle: "Scale used for weather metrics",
                        isHighlighted: matchesCurrentQuery("temperatureUnit")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.temperatureUnit,
                            options: TemperatureUnit.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceRow(
                        title: "Wind Velocity",
                        subtitle: "Unit used for wind speed indicators",
                        isHighlighted: matchesCurrentQuery("windUnit")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.windSpeedUnit,
                            options: WindSpeedUnit.allCases.map { ($0, $0.title) }
                        )
                    }
                }
            }

            if isSectionVisible(["weatherLocation", "weatherRefresh"]) {
                PreferenceSection(
                    title: "LOCATION & REFRESH",
                    isHighlighted: matchesCurrentQuery("weatherLocation") || matchesCurrentQuery("weatherRefresh")
                ) {
                    PreferenceRow(
                        title: "Location Mode",
                        subtitle: "GPS automatic detection or manual city name",
                        isHighlighted: matchesCurrentQuery("weatherLocation")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.weatherLocationMode,
                            options: WeatherLocationMode.allCases.map { ($0, $0.title) }
                        )
                    }

                    if draft.weatherLocationMode == .manualCity {
                        PreferenceRow(
                            title: "City Name",
                            subtitle: "Geocoded for local forecast (e.g. Jakarta, Tokyo, London)",
                            isHighlighted: matchesCurrentQuery("weatherLocation")
                        ) {
                            TextField("City", text: $draft.manualCityName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 164)
                        }
                    }

                    PreferenceRow(
                        title: "Refresh Interval",
                        subtitle: "Background polling frequency",
                        isHighlighted: matchesCurrentQuery("weatherRefresh")
                    ) {
                        ModernMenuPicker(
                            selection: $draft.weatherRefreshMinutes,
                            options: [
                                (1, "Every 1 Minute"),
                                (5, "Every 5 Minutes"),
                                (15, "Every 15 Minutes"),
                                (30, "Every 30 Minutes")
                            ]
                        )
                    }
                }
            }
        }
    }

    // MARK: - 6. System Tab

    private var systemTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            if isSectionVisible(["login", "menuBar"]) {
                PreferenceSection(
                    title: "INTEGRATION",
                    isHighlighted: matchesCurrentQuery("login") || matchesCurrentQuery("menuBar")
                ) {
                    PreferenceToggleRow(
                        title: "Launch at Login",
                        subtitle: "Start Obelisk automatically when you log in",
                        isHighlighted: matchesCurrentQuery("login"),
                        isOn: $draft.launchAtLogin
                    )

                    PreferenceToggleRow(
                        title: "Show Menu Bar Icon",
                        subtitle: "Display an accessory item in the macOS status bar",
                        isHighlighted: matchesCurrentQuery("menuBar"),
                        isOn: $draft.showMenuBarIcon
                    )
                }
            }

            if isSectionVisible(["resetAll", "quit"]) {
                PreferenceSection(
                    title: "MANAGEMENT",
                    isHighlighted: matchesCurrentQuery("resetAll") || matchesCurrentQuery("quit")
                ) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Reset All Preferences")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)

                                if matchesCurrentQuery("resetAll") {
                                Text("MATCH")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(Color.blue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(Color.blue.opacity(0.18)))
                            }
                        }
                        Text("Revert all settings across every tab to clean factory defaults")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer()

                    Button("Reset All...") {
                        showingResetConfirmation = true
                    }
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.leading, 16)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Quit Obelisk")
                                .font(.system(size: 13))
                                .foregroundColor(.white)

                            if matchesCurrentQuery("quit") {
                                Text("MATCH")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(Color.blue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(Color.blue.opacity(0.18)))
                            }
                        }
                        Text("Terminate the background process completely")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer()

                    Button("Quit Obelisk") {
                        NSApp.terminate(nil)
                    }
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
            }
        }
    }
}

    // MARK: - Pinned Live Preview Canvas

    @ViewBuilder
    private var previewControlBar: some View {
        let activeDraft = (isPreviewFrozen && frozenDraft != nil) ? frozenDraft! : draft
        let effectivePreviewTab: ObeliskTab = activeDraft.enabledTabs.contains(previewTab)
            ? previewTab
            : (activeDraft.enabledTabs.first ?? .media)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "display")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.50))
                    Text("LIVE NOTCH PREVIEW")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                        .tracking(0.6)
                }

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                previewExpandedState = false
                                appearanceSubMode = .compact
                            }
                        }) {
                            Text("Compact")
                                .font(.system(size: 11, weight: !previewExpandedState ? .medium : .regular))
                                .foregroundColor(!previewExpandedState ? .white : .white.opacity(0.60))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(!previewExpandedState ? Color.white.opacity(0.18) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                previewExpandedState = true
                                appearanceSubMode = .expanded
                            }
                        }) {
                            Text("Expanded")
                                .font(.system(size: 11, weight: previewExpandedState ? .medium : .regular))
                                .foregroundColor(previewExpandedState ? .white : .white.opacity(0.60))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(previewExpandedState ? Color.white.opacity(0.18) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
                    )

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isPreviewFrozen {
                                isPreviewFrozen = false
                                frozenDraft = nil
                            } else {
                                frozenDraft = draft
                                isPreviewFrozen = true
                            }
                        }
                    }) {
                        HStack(spacing: 5) {
                            Text(isPreviewFrozen ? "Paused" : "Live")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(isPreviewFrozen ? .white.opacity(0.50) : .white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isPreviewFrozen ? Color.white.opacity(0.06) : Color.blue.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(isPreviewFrozen ? Color.white.opacity(0.08) : Color.blue.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if previewExpandedState {
                HStack(spacing: 6) {
                    Text("Tab:")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.40))

                    ForEach(activeDraft.enabledTabs, id: \.rawValue) { tab in
                        let isCurrentTab = (effectivePreviewTab == tab)
                        Button(action: {
                            previewTab = tab
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 8.5))
                                Text(tab.title)
                                    .font(.system(size: 10.5, weight: isCurrentTab ? .semibold : .regular))
                            }
                            .foregroundColor(isCurrentTab ? .white : .white.opacity(0.60))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isCurrentTab ? Color.white.opacity(0.14) : Color.white.opacity(0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .transition(.opacity)
            }
        }
    }

    private var previewCanvas: some View {
        let activeDraft = (isPreviewFrozen && frozenDraft != nil) ? frozenDraft! : draft
        let effectivePreviewTab: ObeliskTab = activeDraft.enabledTabs.contains(previewTab)
            ? previewTab
            : (activeDraft.enabledTabs.first ?? .media)

        return VStack(alignment: .leading, spacing: 8) {
            previewControlBar

            let compactPreviewW: CGFloat = CGFloat(max(190.0, 210.0 + activeDraft.compactWidthOffset * 0.65))
            let compactPreviewH: CGFloat = max(28, CGFloat(32.0 + activeDraft.compactHeightOffset * 0.80))
            // Smoothly map Expanded Width (560...760 pt) across the Bezel Simulator canvas (435...585 pt) so changes are 100% visible in real time
            let clampedExpW = min(760.0, max(560.0, activeDraft.expandedWidth))
            let expandedPreviewW: CGFloat = CGFloat(435.0 + ((clampedExpW - 560.0) / 200.0) * 150.0)
            let expandedPreviewH: CGFloat = max(165, CGFloat(168.0 + activeDraft.expandedHeightOffset))

            let pWidth: CGFloat = previewExpandedState ? expandedPreviewW : compactPreviewW
            let pHeight: CGFloat = previewExpandedState ? expandedPreviewH : compactPreviewH
            let pWingSlot: CGFloat = max(60, (pWidth - 44) / 2)
            let pRadius: CGFloat = previewExpandedState
                ? CGFloat(activeDraft.expandedCornerRadius)
                : CGFloat(activeDraft.compactCornerRadius)
            let pTopEarRadius: CGFloat = previewExpandedState
                ? CGFloat(activeDraft.expandedTopCornerRadius)
                : CGFloat(min(activeDraft.compactTopCornerRadius, 5.0))
            let pColor: Color = (activeDraft.waveformColorMode == .monochromeWhite || activeDraft.colorTheme == .monochrome)
                ? .white.opacity(0.85)
                : activeDraft.resolvedColor(for: .mediaAccent(source: mediaManager.currentTrack.source == .none ? .spotify : mediaManager.currentTrack.source))
            let activePreviewSurface = previewExpandedState ? activeDraft.expandedSurfaceStyle : activeDraft.compactSurfaceStyle
            let currentBlur = previewExpandedState ? activeDraft.expandedGlassBlur : activeDraft.compactGlassBlur
            let currentOpacity = previewExpandedState ? activeDraft.expandedOpacity : activeDraft.compactOpacity
            let pStrokeColor: Color = activePreviewSurface == .ambientGlow
                ? pColor.opacity(min(0.6, activeDraft.borderOpacity * 2.2))
                : Color.white.opacity(activeDraft.borderOpacity)
            let previewBatColor: Color = activeDraft.resolvedColor(for: .battery(isLow: false))
            let previewCpuColor: Color = activeDraft.resolvedColor(for: .cpu)
            let previewWeatherPrimary: Color = activeDraft.resolvedColor(for: .weatherPrimary)
            let containerH: CGFloat = previewExpandedState ? max(195, pHeight + 24) : max(74, pHeight + 24)

            // Display Bezel Simulator
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 22/255, green: 22/255, blue: 25/255))

                // Simulated MacBook Top Bezel bar
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 10)

                // Simulated Notch
                ZStack(alignment: .top) {
                    if !previewExpandedState {
                        previewCompactNotch(
                            draftToUse: activeDraft,
                            pWingSlot: pWingSlot,
                            pColor: pColor,
                            previewBatColor: previewBatColor,
                            previewCpuColor: previewCpuColor,
                            previewWeatherPrimary: previewWeatherPrimary
                        )
                        .frame(width: pWidth, height: pHeight)
                    } else {
                        previewExpandedNotch(
                            draftToUse: activeDraft,
                            currentTab: effectivePreviewTab,
                            pColor: pColor
                        )
                        .frame(width: pWidth, height: pHeight)
                    }
                }
                .brightness((activeDraft.colorBrightness - 1.0) * 0.40)
                .background(
                    ZStack {
                        switch activePreviewSurface {
                        case .pitchBlack:
                            Color.black.opacity(currentOpacity)
                        case .liquidGlass:
                            NotchLiquidGlassSurface(
                                bottomRadius: pRadius,
                                topEarRadius: pTopEarRadius,
                                blur: currentBlur,
                                opacity: currentOpacity,
                                isExpanded: previewExpandedState,
                                tint: nil,
                                drawsBorder: false
                            )
                        case .darkGlass:
                            NotchLiquidGlassSurface(
                                bottomRadius: pRadius,
                                topEarRadius: pTopEarRadius,
                                blur: currentBlur,
                                opacity: currentOpacity,
                                isExpanded: previewExpandedState,
                                tint: Color.black.opacity(0.55),
                                drawsBorder: false
                            )
                        case .frostedGlass:
                            ZStack {
                                Color(red: 14/255, green: 14/255, blue: 18/255).opacity(0.95)
                                LinearGradient(
                                    colors: [Color.white.opacity(0.05), Color.clear],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            }
                            .opacity(currentOpacity)
                        case .ambientGlow:
                            ZStack {
                                Color.black
                                LinearGradient(
                                    colors: [pColor.opacity(0.22), Color.clear],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            }
                            .opacity(currentOpacity)
                        }

                        if activeDraft.showBorder {
                            if activePreviewSurface.isLiquidGlass {
                                UnderNotchBorder(bottomRadius: pRadius, topEarRadius: pTopEarRadius)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(min(0.24, activeDraft.borderOpacity * 0.40)),
                                                Color.white.opacity(min(0.08, activeDraft.borderOpacity * 0.15)),
                                                Color.white.opacity(min(0.18, activeDraft.borderOpacity * 0.30))
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: max(0.5, CGFloat(activeDraft.borderWidth))
                                    )
                            } else {
                                UnderNotchBorder(bottomRadius: pRadius, topEarRadius: pTopEarRadius)
                                    .stroke(pStrokeColor, lineWidth: CGFloat(activeDraft.borderWidth))
                            }
                        }
                    }
                )
                .clipShape(NotchShape(bottomRadius: pRadius, topEarRadius: pTopEarRadius))
                .shadow(color: Color.black.opacity(0.40), radius: 6, y: 3)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: previewExpandedState)
            }
            .frame(height: containerH)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .padding(12)
        .background(Color(red: 22/255, green: 22/255, blue: 25/255))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Preview Compact & Expanded Views

    @ViewBuilder
    private func previewCompactNotch(
        draftToUse: ObeliskSettingsDraft,
        pWingSlot: CGFloat,
        pColor: Color,
        previewBatColor: Color,
        previewCpuColor: Color,
        previewWeatherPrimary: Color
    ) -> some View {
        HStack(spacing: 0) {
            HStack {
                if draftToUse.compactWingMode != .alwaysMinimal {
                    switch draftToUse.leftWingContent {
                    case .hidden:
                        EmptyView()
                    case .weatherMini:
                        HStack(spacing: 2) {
                            Image(systemName: weatherService.weather.iconName)
                                .font(.system(size: 9))
                                .foregroundColor(previewWeatherPrimary)
                            Text("\(draftToUse.convertedTemperature(weatherService.weather.temperature))°")
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(.white)
                        }
                    case .batteryStatus:
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8))
                                .foregroundColor(previewBatColor)
                            Text("\(HardwareTelemetryService.shared.batteryPercentage)%")
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(.white)
                        }
                    case .cpuLoad:
                        let cpuVal = Int(round(HardwareTelemetryService.shared.cpuUsagePercent))
                        HStack(spacing: 2) {
                            Image(systemName: "cpu")
                                .font(.system(size: 8))
                                .foregroundColor(previewCpuColor)
                            Text("\(cpuVal)%")
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(.white)
                        }
                    case .sourceLogoOnly:
                        SourceLogoView(source: mediaManager.currentTrack.source == .none ? .spotify : mediaManager.currentTrack.source, size: 14)
                    case .artworkOrLogo:
                        if let img = mediaManager.artworkImage {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 16, height: 16)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        } else {
                            SourceLogoView(source: mediaManager.currentTrack.source == .none ? .spotify : mediaManager.currentTrack.source, size: 14)
                        }
                    }
                }
            }
            .frame(width: pWingSlot, alignment: .leading)

            Spacer()

            Circle()
                .fill(Color(red: 18/255, green: 28/255, blue: 22/255))
                .frame(width: 6, height: 6)

            Spacer()

            HStack {
                if draftToUse.compactWingMode != .alwaysMinimal {
                    switch draftToUse.rightWingStyle {
                    case .hidden:
                        EmptyView()
                    case .equalizerBars:
                        HStack(alignment: .bottom, spacing: 1.5) {
                            RoundedRectangle(cornerRadius: 1).fill(pColor).frame(width: 2, height: 5)
                            RoundedRectangle(cornerRadius: 1).fill(pColor).frame(width: 2, height: 12)
                            RoundedRectangle(cornerRadius: 1).fill(pColor).frame(width: 2, height: 8)
                            RoundedRectangle(cornerRadius: 1).fill(pColor).frame(width: 2, height: 14)
                        }
                        .frame(height: 15)
                    case .sineWave:
                        HStack(alignment: .bottom, spacing: 1.5) {
                            RoundedRectangle(cornerRadius: 1).fill(pColor).frame(width: 2, height: 6)
                            RoundedRectangle(cornerRadius: 1).fill(pColor).frame(width: 2, height: 12)
                            RoundedRectangle(cornerRadius: 1).fill(pColor).frame(width: 2, height: 9)
                            RoundedRectangle(cornerRadius: 1).fill(pColor).frame(width: 2, height: 5)
                        }
                        .frame(height: 15)
                    case .minimalDots:
                        HStack(spacing: 2) {
                            Circle().fill(pColor).frame(width: 2.5, height: 2.5)
                            Circle().fill(pColor.opacity(0.85)).frame(width: 2.5, height: 2.5)
                            Circle().fill(pColor.opacity(0.60)).frame(width: 2.5, height: 2.5)
                        }
                    case .elapsedTimer:
                        let timerClr = draftToUse.compactTimerColorMode == .monochromeWhite ? Color.white.opacity(0.85) : pColor
                        CompactTimerWithProgressBar(
                            positionText: "1:42",
                            timerColor: timerClr,
                            progressColor: pColor,
                            duration: 210,
                            position: 102
                        )
                    case .batteryOrPrivacy:
                        Text("\(HardwareTelemetryService.shared.batteryPercentage)%")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(.white)
                    case .systemTelemetry:
                        let cpuPct = Int(round(HardwareTelemetryService.shared.cpuUsagePercent))
                        Text("\(cpuPct)%")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: pWingSlot, alignment: .trailing)
        }
        .padding(.horizontal, 8)
    }

    private var batteryStatusSubtitle: String {
        let telemetry = HardwareTelemetryService.shared
        if telemetry.isCharging {
            if let mins = telemetry.timeRemainingMinutes, mins > 0 {
                let h = mins / 60
                let m = mins % 60
                return h > 0 ? "\(h)h \(m)m until full" : "\(m)m until full"
            } else if telemetry.batteryPercentage >= 100 {
                return "Fully Charged"
            } else {
                return "Charging"
            }
        } else if telemetry.isPluggedIn {
            return telemetry.batteryPercentage >= 100 ? "Fully Charged" : "Power Adapter"
        } else {
            if let mins = telemetry.timeRemainingMinutes, mins > 0 {
                let h = mins / 60
                let m = mins % 60
                return "\(h > 0 ? "\(h)h \(m)m" : "\(m)m") Left"
            }
            return "On Battery"
        }
    }

    @ViewBuilder
    private func previewExpandedNotch(
        draftToUse: ObeliskSettingsDraft,
        currentTab: ObeliskTab,
        pColor: Color
    ) -> some View {
        let pTopClearance = CGFloat(max(10, 14.0 + draftToUse.topNotchClearanceOffset * 0.40))
        let contentInset = CGFloat(max(18, draftToUse.expandedTopCornerRadius + 8))

        VStack(spacing: 6) {
            // Header Bar matching live ExpandedNotchView
            HStack(spacing: 12) {
                // Floating navigation tabs
                HStack(spacing: 12) {
                    ForEach(draftToUse.enabledTabs, id: \.rawValue) { tab in
                        let isSelected = currentTab == tab
                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                previewTab = tab
                            }
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.40))

                                if isSelected {
                                    Circle()
                                        .fill(pColor)
                                        .frame(width: 3.5, height: 3.5)
                                } else {
                                    Color.clear
                                        .frame(width: 3.5, height: 3.5)
                                }
                            }
                            .frame(height: 22)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 2)

                Spacer()

                // Floating battery status
                HStack(spacing: 5) {
                    BatteryPillBadge(
                        percentage: HardwareTelemetryService.shared.batteryPercentage,
                        isCharging: HardwareTelemetryService.shared.isCharging
                    )

                    Text("\(HardwareTelemetryService.shared.batteryPercentage)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(
                            HardwareTelemetryService.shared.isCharging
                                ? Color(red: 52/255, green: 199/255, blue: 89/255)
                                : (HardwareTelemetryService.shared.batteryPercentage <= 20 ? Color(red: 255/255, green: 69/255, blue: 58/255) : .white)
                        )

                    let sub = batteryStatusSubtitle
                    if !sub.isEmpty {
                        Text("•")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))

                        Text(sub)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }

                // Camera Mirror & Settings Actions
                HStack(spacing: 8) {
                    Image(systemName: "web.camera")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.60))
                        .frame(width: 20, height: 20)

                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.60))
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, contentInset)
            .padding(.top, pTopClearance)

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, contentInset - 4)

            // Dynamic Tab Content (100% precision live page mirroring live notch)
            NotchPageView(tab: currentTab)
                .padding(.horizontal, contentInset)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - Native macOS Inset Grouped Components

/// Grouped card container mimicking macOS System Settings with uppercase section headers
/// and continuous rounded card styling.
struct PreferenceSection<Content: View>: View {
    let title: String
    var isHighlighted: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isHighlighted ? Color.blue.opacity(0.9) : Color.white.opacity(0.42))
                    .tracking(0.6)
            }
            .padding(.leading, 6)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .background(Color(red: 24/255, green: 24/255, blue: 27/255))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isHighlighted ? Color.blue.opacity(0.35) : Color.white.opacity(0.06),
                        lineWidth: isHighlighted ? 1.0 : 0.5
                    )
            )
        }
    }
}

/// Base preference row with title, optional description, trailing control, and hairline separator.
struct PreferenceRow<Control: View>: View {
    let title: String
    var subtitle: String? = nil
    var isHighlighted: Bool = false
    @ViewBuilder let control: () -> Control

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white)

                        if isHighlighted {
                            Text("MATCH")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(Color.blue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.blue.opacity(0.18)))
                        }
                    }

                    if let sub = subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.48))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 16)

                control()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isHighlighted ? Color.blue.opacity(0.06) : Color.clear)
        }
    }
}

/// Standard preference row with a toggle switch, tinted in macOS accent blue.
struct PreferenceToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var isHighlighted: Bool = false
    @Binding var isOn: Bool

    var body: some View {
        PreferenceRow(title: title, subtitle: subtitle, isHighlighted: isHighlighted) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Color.blue)
        }
    }
}

/// Display format mode for preference sliders.
enum SliderDisplayMode {
    case normalized0To100
    case milliseconds
    case signedMilliseconds
}

/// Custom ultra-smooth slider with a round circular thumb and zero tick marks ("tidak ada garis berdiri").
struct SmoothCircularSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil

    @State private var isDragging: Bool = false
    @State private var isHovered: Bool = false

    private let knobDiameter: CGFloat = 16
    private var knobRadius: CGFloat { knobDiameter / 2 }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let travel = max(1.0, width - knobDiameter)
            let fraction = max(0.0, min(1.0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            let knobX = knobRadius + CGFloat(fraction) * travel

            ZStack(alignment: .leading) {
                // Inactive track pill
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 5)

                // Active filled track pill
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.16, green: 0.48, blue: 0.96), Color(red: 0.24, green: 0.56, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(knobDiameter, knobX + knobRadius), height: 5)

                // Circular knob thumb (tombol bulat)
                Circle()
                    .fill(Color.white)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(isDragging ? 0.45 : 0.28), radius: isDragging ? 3.5 : 2.5, y: 1.5)
                    .scaleEffect(isDragging ? 1.12 : (isHovered ? 1.06 : 1.0))
                    .offset(x: knobX - knobRadius)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        updateValue(at: gesture.location.x, totalWidth: width)
                    }
                    .onEnded { gesture in
                        updateValue(at: gesture.location.x, totalWidth: width)
                        withAnimation(.easeOut(duration: 0.15)) {
                            isDragging = false
                        }
                    }
            )
            .pointingHandCursor()
        }
        .frame(height: 22)
    }

    private func updateValue(at x: CGFloat, totalWidth: CGFloat) {
        let travel = max(1.0, totalWidth - knobDiameter)
        let fraction = Double(max(0.0, min(1.0, (x - knobRadius) / travel)))
        var rawValue = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        if let step = step, step > 0 {
            rawValue = range.lowerBound + (round((rawValue - range.lowerBound) / step) * step)
        }
        value = min(range.upperBound, max(range.lowerBound, rawValue))
    }
}

/// Standard preference row with a smooth circular slider and clean monospace value readout.
struct PreferenceSliderRow: View {
    let title: String
    var subtitle: String? = nil
    var mode: SliderDisplayMode = .normalized0To100
    var isHighlighted: Bool = false
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil

    private var normalizedBinding: Binding<Double> {
        Binding<Double>(
            get: {
                let clamped = min(range.upperBound, max(range.lowerBound, value))
                let span = range.upperBound - range.lowerBound
                guard span > 0 else { return 0 }
                return ((clamped - range.lowerBound) / span) * 100.0
            },
            set: { newNorm in
                let fraction = min(100.0, max(0.0, newNorm)) / 100.0
                let physical = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                value = physical
            }
        )
    }

    private var displayedValueText: String {
        switch mode {
        case .normalized0To100:
            let clamped = min(range.upperBound, max(range.lowerBound, value))
            let span = range.upperBound - range.lowerBound
            let n = span > 0 ? Int(round(((clamped - range.lowerBound) / span) * 100.0)) : 0
            return "\(n)"
        case .milliseconds:
            let ms = Int(round(value))
            return "\(ms) ms"
        case .signedMilliseconds:
            let ms = Int(round(value))
            return String(format: "%+d ms", ms)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white)

                            if isHighlighted {
                                Text("MATCH")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(Color.blue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(Color.blue.opacity(0.18)))
                            }
                        }

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }

                    Spacer()

                    Text(displayedValueText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
                }

                if mode == .normalized0To100 {
                    SmoothCircularSlider(
                        value: normalizedBinding,
                        range: 0...100,
                        step: 1.0
                    )
                } else {
                    SmoothCircularSlider(
                        value: $value,
                        range: range,
                        step: step
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isHighlighted ? Color.blue.opacity(0.06) : Color.clear)
        }
    }
}

/// Modern custom menu picker mimicking sleek modern macOS dropdowns with smooth hover
struct ModernMenuPicker<T: Equatable>: View {
    @Binding var selection: T
    let options: [(value: T, title: String)]
    var width: CGFloat = 164

    @State private var isHovered: Bool = false

    private var currentTitle: String {
        options.first(where: { $0.value == selection })?.title ?? ""
    }

    var body: some View {
        Menu {
            ForEach(options.indices, id: \.self) { idx in
                let item = options[idx]
                Button(action: {
                    selection = item.value
                }) {
                    HStack {
                        Text(item.title)
                        if selection == item.value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(currentTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.90))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(width: width)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.10), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isHovered = $0 }
    }
}

/// Refined Apple macOS native styled button with subtle rounded corners and clean typography
struct ModernButton: View {
    let title: String
    var icon: String? = nil
    var isProminent: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: isProminent ? .semibold : .medium))
                }
                Text(title)
                    .font(.system(size: 12, weight: isProminent ? .semibold : .medium))
            }
            .foregroundColor(
                isProminent ? Color.white :
                isDestructive ? (isHovered ? Color.red.opacity(0.95) : Color.white.opacity(0.85)) :
                Color.white.opacity(0.88)
            )
            .padding(.horizontal, 11)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .fill(
                        isProminent
                            ? Color.blue.opacity(isHovered ? 0.95 : 0.85)
                            : Color.white.opacity(isHovered ? 0.12 : 0.06)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .stroke(
                        isProminent
                            ? Color.blue.opacity(0.35)
                            : Color.white.opacity(isHovered ? 0.16 : 0.09),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preferences NSWindow Controller

@MainActor
public final class SettingsWindowManager: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowManager()
    private var window: NSWindow?
    public private(set) var isSettingsOpen: Bool = false

    public func showSettings() {
        self.isSettingsOpen = true
        NSApp.setActivationPolicy(.regular)
        WindowManager.shared.updateCompactWidth(animated: true)

        if let existing = window {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
            existing.collectionBehavior = [.moveToActiveSpace]
            existing.level = .normal
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Obelisk Preferences"
        settingsWindow.titlebarAppearsTransparent = true
        settingsWindow.titleVisibility = .hidden
        settingsWindow.backgroundColor = NSColor(red: 16/255, green: 16/255, blue: 18/255, alpha: 1.0)
        settingsWindow.appearance = NSAppearance(named: .darkAqua)
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.collectionBehavior = [.moveToActiveSpace]
        settingsWindow.level = .normal
        settingsWindow.delegate = self
        settingsWindow.center()

        let hosting = NSHostingView(rootView: SettingsView())
        settingsWindow.contentView = hosting

        self.window = settingsWindow
        settingsWindow.makeKeyAndOrderFront(nil)
        settingsWindow.makeFirstResponder(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        self.window = nil
        self.isSettingsOpen = false
        NSApp.setActivationPolicy(.accessory)
        WindowManager.shared.updateCompactWidth(animated: true)
    }
}
