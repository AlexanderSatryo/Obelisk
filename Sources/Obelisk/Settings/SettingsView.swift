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

/// Structured search index item with multi-keyword mapping in English
public struct SettingsSearchItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let category: SettingsCategory
    public let keywords: [String]

    public func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return false }
        if title.lowercased().contains(q) { return true }
        if category.rawValue.lowercased().contains(q) { return true }
        return keywords.contains { $0.lowercased().contains(q) }
    }
}

/// Comprehensive deep index of all settings options across Obelisk
public enum SettingsSearchIndex {
    public static let allItems: [SettingsSearchItem] = [
        // Appearance
        SettingsSearchItem(id: "surface", title: "Surface Material (Standby & Hover)", category: .appearance, keywords: ["surface", "material", "standby", "hover", "extend", "standby material", "expanded material", "liquid glass", "dark liquid glass", "dark glass", "frosted glass", "pitch black", "ambient glow", "apple glass", "oled"]),
        SettingsSearchItem(id: "opacity", title: "Notch Opacity", category: .appearance, keywords: ["opacity", "transparency", "notch opacity", "surface opacity", "transparent", "alpha", "blur", "see through"]),
        SettingsSearchItem(id: "border", title: "Hairline Rim Border", category: .appearance, keywords: ["border", "hairline rim", "stroke", "rim", "edge", "border width", "border opacity"]),
        SettingsSearchItem(id: "theme", title: "Color Preset Theme", category: .appearance, keywords: ["color theme", "color preset", "theme", "color", "palette", "soft", "colorful", "monochrome", "brightness"]),
        SettingsSearchItem(id: "geometry", title: "Geometry & Dimensions", category: .appearance, keywords: ["geometry", "compact width", "compact height", "expanded width", "radius", "width", "height", "dimensions", "offset", "size"]),
        SettingsSearchItem(id: "topCornerRadius", title: "Top Bezel Corner Radius", category: .appearance, keywords: ["top radius", "top corner radius", "bezel", "ears", "compact top radius", "expanded top radius", "curvature"]),
        SettingsSearchItem(id: "bottomCornerRadius", title: "Bottom Corner Radius", category: .appearance, keywords: ["bottom radius", "bottom corner radius", "compact radius", "expanded radius", "corner radius", "curvature"]),
        SettingsSearchItem(id: "standbyHUD", title: "Standby HUD Layout", category: .appearance, keywords: ["hud", "standby hud", "hud layout", "hud style", "volume", "brightness", "charge", "charging", "connected", "disconnected", "caps lock", "caps", "keyboard", "side expansion", "horizontal wings", "downward card", "extended card"]),
        SettingsSearchItem(id: "compactWings", title: "Compact Wings Mode", category: .appearance, keywords: ["compact wings", "wing expansion", "always minimal", "dynamic auto", "always wide", "wings"]),
        SettingsSearchItem(id: "leftWing", title: "Left Wing Content", category: .appearance, keywords: ["left wing", "weather mini", "battery status", "clock", "camera", "logo", "artwork", "battery", "cpu", "thumbnail"]),
        SettingsSearchItem(id: "rightWing", title: "Right Wing Style", category: .appearance, keywords: ["right wing", "waveform", "visualizer", "audio wave", "equalizer bars", "battery", "telemetry", "timer", "minimal dots"]),
        SettingsSearchItem(id: "waveformColor", title: "Waveform Color Mode", category: .appearance, keywords: ["waveform color", "waveform", "audio wave", "media accent", "monochrome white"]),
        SettingsSearchItem(id: "timerColor", title: "Compact Timer Color", category: .appearance, keywords: ["timer color", "compact timer", "playback timer", "timer accent"]),

        // Behavior
        SettingsSearchItem(id: "trigger", title: "Trigger Mode", category: .behavior, keywords: ["trigger mode", "hover", "click", "dwell latency", "grace period", "interaction"]),
        SettingsSearchItem(id: "animation", title: "Animation Speed", category: .behavior, keywords: ["animation speed", "spring", "snappy", "balanced", "fluid", "animation curves", "transition"]),
        SettingsSearchItem(id: "gestures", title: "Trackpad Gestures & Swipe", category: .behavior, keywords: ["gestures", "trackpad", "swipe", "two-finger page swipe"]),

        // Modules
        SettingsSearchItem(id: "mediaModule", title: "Media Player Module", category: .modules, keywords: ["media player", "music", "spotify", "apple music", "youtube", "playback"]),
        SettingsSearchItem(id: "weatherModule", title: "Weather Module", category: .modules, keywords: ["weather", "forecast", "temperature", "rain", "precipitation", "conditions"]),
        SettingsSearchItem(id: "calendarModule", title: "Calendar Module", category: .modules, keywords: ["calendar", "schedule", "agenda", "events", "date"]),
        SettingsSearchItem(id: "fileModule", title: "File Tray & AirDrop Module", category: .modules, keywords: ["file", "airdrop", "tray", "shelf", "drop", "drag and drop", "file shelf", "share"]),
        SettingsSearchItem(id: "defaultOpeningTab", title: "Opening Tab / Default View", category: .modules, keywords: ["opening tab", "default view", "remember last open", "default opening tab", "initial tab"]),
        SettingsSearchItem(id: "fileTrayCapacity", title: "File Shelf Capacity", category: .modules, keywords: ["shelf capacity", "file shelf capacity", "tray capacity", "file limit"]),
        SettingsSearchItem(id: "autoClearAfterAirDrop", title: "Auto-Clear After AirDrop", category: .modules, keywords: ["auto-clear", "clear after airdrop", "automatic clear", "empty shelf"]),
        SettingsSearchItem(id: "calendarEventDots", title: "Calendar Event Indicators", category: .modules, keywords: ["calendar event", "event dots", "event indicators", "agenda markers", "event badge"]),
        SettingsSearchItem(id: "downloads", title: "Live Downloads & Task Progress", category: .modules, keywords: ["download", "downloads", "progress", "live activities", "download progress", "crdownload", "task progress"]),
        SettingsSearchItem(id: "notifications", title: "Dynamic Island Notifications & Touch ID", category: .modules, keywords: ["notification", "notifications", "touch id", "face id", "biometrics", "privacy", "whatsapp", "mail", "telegram", "messages", "dynamic island notifications", "lock", "filter", "category", "entertainment", "social media", "productivity"]),

        // Media & Lyrics
        SettingsSearchItem(id: "lyrics", title: "Synchronized Lyrics", category: .media, keywords: ["synchronized lyrics", "lyrics", "live lyrics", "synced lyrics", "auto-expand lyrics"]),
        SettingsSearchItem(id: "lyricsScale", title: "Lyrics Typography Scale", category: .media, keywords: ["typography scale", "lyrics font scale", "lyrics typography", "font size", "text scale"]),
        SettingsSearchItem(id: "lyricsOffset", title: "Lyrics Timing Offset", category: .media, keywords: ["lyrics timing offset", "lyrics offset", "lyrics delay", "lyrics sync", "timing offset"]),
        SettingsSearchItem(id: "seekInterval", title: "Video Seek Interval", category: .media, keywords: ["seek interval", "video seek", "skip interval", "rewind", "fast-forward", "scrub interval"]),

        // Weather
        SettingsSearchItem(id: "temperatureUnit", title: "Temperature Unit", category: .weather, keywords: ["temperature unit", "celsius", "fahrenheit", "temperature scale", "degrees"]),
        SettingsSearchItem(id: "windUnit", title: "Wind Velocity Unit", category: .weather, keywords: ["wind velocity", "wind speed", "km/h", "mph", "m/s"]),
        SettingsSearchItem(id: "weatherLocation", title: "Location Mode", category: .weather, keywords: ["location mode", "gps", "geolocation", "city name", "geocoded", "manual location"]),
        SettingsSearchItem(id: "weatherRefresh", title: "Weather Refresh Interval", category: .weather, keywords: ["refresh interval", "polling interval", "weather update frequency", "refresh rate"]),

        // System
        SettingsSearchItem(id: "login", title: "Launch at Login", category: .system, keywords: ["launch at login", "startup", "autostart", "login items"]),
        SettingsSearchItem(id: "menuBar", title: "Show Menu Bar Icon", category: .system, keywords: ["menu bar icon", "status bar", "status bar icon", "menu bar"]),
        SettingsSearchItem(id: "resetAll", title: "Reset All Preferences", category: .system, keywords: ["reset all", "reset defaults", "restore factory defaults", "reset preferences"]),
        SettingsSearchItem(id: "quit", title: "Quit Obelisk", category: .system, keywords: ["quit", "exit", "terminate", "close application"])
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
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var previewExpandedState: Bool = false
    @State private var previewTab: ObeliskTab = .media
    @State private var showSavedMessage: Bool = false
    @State private var isPreviewFrozen: Bool = false
    @State private var frozenDraft: ObeliskSettingsDraft? = nil
    @State private var hasUnsavedChanges: Bool = false

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
            // MARK: - Left macOS System Settings Sidebar
            sidebarView
                .frame(width: 236)
                .background(Color(red: 22/255, green: 22/255, blue: 25/255))

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)

            // MARK: - Right Detail Content Area
            VStack(spacing: 0) {
                // macOS Category Header
                detailHeaderView

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Pinned Live Preview (when in Appearance)
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
                            searchBannerView
                        }

                        if !searchText.isEmpty && matchingItemCount(for: selectedCategory) == 0 {
                            noResultsForCategoryView
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
                }

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Bottom Action Footer
                detailFooterView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 16/255, green: 16/255, blue: 18/255))
        }
        .frame(width: 840, height: 620)
        .background(Color(red: 16/255, green: 16/255, blue: 18/255))
        .preferredColorScheme(.dark)
        .onAppear {
            let initial = settings.makeDraft()
            draft = initial
            savedSnapshot = initial
            hasUnsavedChanges = false
            isSearchFocused = false
        }
        .onChange(of: draft) { newDraft in
            hasUnsavedChanges = (newDraft != savedSnapshot)
        }
        .onChange(of: searchText) { newQuery in
            let q = newQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return }
            if !filteredCategories.contains(selectedCategory), let first = filteredCategories.first {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    selectedCategory = first
                }
            }
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
                    ForEach(filteredCategories) { category in
                        let isSelected = (selectedCategory == category)
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedCategory = category
                            }
                        }) {
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

                                let matchCount = matchingItemCount(for: category)
                                if matchCount > 0 {
                                    Text("\(matchCount)")
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
                }
                .padding(.horizontal, 8)
            }

            Spacer()
        }
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

            ModernButton(
                title: "Reset to Defaults",
                icon: "arrow.counterclockwise"
            ) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    draft.resetCategoryToDefaults(selectedCategory)
                }
            }
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
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 255/255, green: 175/255, blue: 60/255))
                        .frame(width: 7, height: 7)
                    Text("Previewing changes in canvas above")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.78, blue: 0.45))
                        .frame(width: 7, height: 7)
                    Text("All settings in sync with notch")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.70))
                }
            }

            Spacer()

            if hasUnsavedChanges {
                ModernButton(title: "Discard", icon: "xmark") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        draft = savedSnapshot
                        hasUnsavedChanges = false
                    }
                }
            }

            ModernButton(
                title: "Save Changes",
                icon: "checkmark",
                isProminent: true
            ) {
                saveSettings()
            }
            .disabled(!hasUnsavedChanges && !showSavedMessage)
            .opacity(!hasUnsavedChanges && !showSavedMessage ? 0.45 : 1.0)
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

    // MARK: - Search Banners & Fallbacks

    private var searchBannerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.blue)

            let total = totalMatchingItems
            Text("Search: \"\(searchText)\" • \(total) setting\(total == 1 ? "" : "s") found across Obelisk")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            Spacer()

            Button(action: {
                searchText = ""
                isSearchFocused = false
            }) {
                Text("Clear")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.blue)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.blue.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.blue.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var noResultsForCategoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.white.opacity(0.35))
                .padding(.top, 14)

            Text("No settings in \(selectedCategory.rawValue) match \"\(searchText)\"")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.70))

            let otherMatches = filteredCategories.filter { $0 != selectedCategory && matchingItemCount(for: $0) > 0 }
            if !otherMatches.isEmpty {
                Text("Matching settings found in other sections:")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    ForEach(otherMatches) { cat in
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedCategory = cat
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10))
                                Text(cat.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                Text("\(matchingItemCount(for: cat))")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.blue.opacity(0.25)))
                            }
                            .foregroundColor(Color.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.blue.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - 1. Appearance Tab

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Surface & Border
            if isSectionVisible(["surface", "opacity", "border"]) {
                PreferenceSection(
                    title: "SURFACE & BORDER",
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

                    PreferenceSliderRow(
                        title: "Notch Opacity",
                        isHighlighted: matchesCurrentQuery("opacity"),
                        value: $draft.notchOpacity,
                        range: 0.20...1.00
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
                            isHighlighted: matchesCurrentQuery("border"),
                            value: $draft.borderOpacity,
                            range: 0.04...0.40
                        )
                    }
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

            // Geometry & Dimensions
            if isSectionVisible(["geometry", "topCornerRadius", "bottomCornerRadius"]) {
                PreferenceSection(
                    title: "GEOMETRY",
                    isHighlighted: matchesCurrentQuery("geometry") || matchesCurrentQuery("topCornerRadius") || matchesCurrentQuery("bottomCornerRadius")
                ) {
                    PreferenceSliderRow(
                        title: "Compact Width Offset",
                        isHighlighted: matchesCurrentQuery("geometry"),
                        value: $draft.compactWidthOffset,
                        range: 40...380
                    )

                    PreferenceSliderRow(
                        title: "Compact Height Offset",
                        isHighlighted: matchesCurrentQuery("geometry"),
                        value: $draft.compactHeightOffset,
                        range: -4...24
                    )

                    PreferenceRow(
                        title: "Expanded Width Preset",
                        subtitle: "Quick size profile for the expanded notch",
                        isHighlighted: matchesCurrentQuery("geometry")
                    ) {
                        ModernMenuPicker(
                            selection: Binding(
                                get: { draft.expandedWidthPreset },
                                set: { newPreset in
                                    draft.expandedWidthPreset = newPreset
                                    draft.expandedWidth = Double(newPreset.width)
                                }
                            ),
                            options: ExpandedWidthPreset.allCases.map { ($0, $0.title) }
                        )
                    }

                    PreferenceSliderRow(
                        title: "Expanded Width",
                        isHighlighted: matchesCurrentQuery("geometry"),
                        value: $draft.expandedWidth,
                        range: 560...760
                    )

                    PreferenceSliderRow(
                        title: "Expanded Height Offset",
                        isHighlighted: matchesCurrentQuery("geometry"),
                        value: $draft.expandedHeightOffset,
                        range: -24...100
                    )

                    PreferenceSliderRow(
                        title: "Compact Top Radius (Bezel)",
                        isHighlighted: matchesCurrentQuery("topCornerRadius"),
                        value: $draft.compactTopCornerRadius,
                        range: 0...16
                    )

                    PreferenceSliderRow(
                        title: "Expanded Top Radius (Bezel)",
                        isHighlighted: matchesCurrentQuery("topCornerRadius"),
                        value: $draft.expandedTopCornerRadius,
                        range: 0...20
                    )

                    PreferenceSliderRow(
                        title: "Compact Bottom Radius",
                        isHighlighted: matchesCurrentQuery("bottomCornerRadius") || matchesCurrentQuery("geometry"),
                        value: $draft.compactCornerRadius,
                        range: 8...18
                    )

                    PreferenceSliderRow(
                        title: "Expanded Bottom Radius",
                        isHighlighted: matchesCurrentQuery("bottomCornerRadius") || matchesCurrentQuery("geometry"),
                        value: $draft.expandedCornerRadius,
                        range: 12...26
                    )
                }
            }

            // Wings & Waveform
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
                        mode: .milliseconds,
                        isHighlighted: matchesCurrentQuery("trigger"),
                        value: $draft.hoverDwellMs,
                        range: 30...300,
                        step: 5
                    )

                    PreferenceSliderRow(
                        title: "Exit Grace Period",
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
                            subtitle: "Reverse swipe navigation direction",
                            isHighlighted: matchesCurrentQuery("gestures"),
                            isOn: $draft.invertHorizontalSwipe
                        )
                    }
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
                        title: "Notifications",
                        subtitle: "Recent notifications history and alert center",
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
                        title: "Notifications HUD",
                        subtitle: "Enable or disable incoming alert popups in the Dynamic Island notch",
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
                            range: 5...30
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
                            selection: $draft.defaultOpeningTab,
                            options: DefaultOpeningTab.allCases.map { ($0, $0.title) },
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
                        subtitle: "Seconds skipped on rewind or fast-forward",
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
                            subtitle: "Geocoded for local forecast",
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

                    ModernButton(
                        title: "Reset All",
                        icon: "arrow.counterclockwise.circle",
                        isDestructive: true
                    ) {
                        draft = ObeliskSettingsDraft()
                    }
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

                    ModernButton(
                        title: "Quit",
                        icon: "power",
                        isDestructive: true
                    ) {
                        NSApp.terminate(nil)
                    }
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

        HStack {
            HStack(spacing: 5) {
                Image(systemName: "display")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.50))
                Text("LIVE NOTCH PREVIEW")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.50))
                    .tracking(0.6)
            }

            Spacer()

            if previewExpandedState {
                HStack(spacing: 3) {
                    ForEach(activeDraft.enabledTabs, id: \.rawValue) { tab in
                        let isCurrentTab = (effectivePreviewTab == tab)
                        Button(action: {
                            previewTab = tab
                        }) {
                            Text(tab.title)
                                .font(.system(size: 10, weight: isCurrentTab ? .semibold : .regular))
                                .foregroundColor(isCurrentTab ? .white : .white.opacity(0.55))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isCurrentTab ? Color.white.opacity(0.12) : Color.clear)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: {
                if isPreviewFrozen {
                    isPreviewFrozen = false
                    frozenDraft = nil
                } else {
                    frozenDraft = draft
                    isPreviewFrozen = true
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isPreviewFrozen ? "lock.fill" : "lock.open")
                        .font(.system(size: 8.5))
                    Text(isPreviewFrozen ? "Frozen" : "Live")
                        .font(.system(size: 9.5, weight: .medium))
                }
                .foregroundColor(isPreviewFrozen ? .white : .white.opacity(0.65))
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isPreviewFrozen ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                )
            }
            .buttonStyle(.plain)

            Picker("", selection: $previewExpandedState) {
                Text("Compact").tag(false)
                Text("Expanded").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
        }
    }

    private var previewCanvas: some View {
        let activeDraft = (isPreviewFrozen && frozenDraft != nil) ? frozenDraft! : draft
        let effectivePreviewTab: ObeliskTab = activeDraft.enabledTabs.contains(previewTab)
            ? previewTab
            : (activeDraft.enabledTabs.first ?? .media)

        return VStack(alignment: .leading, spacing: 8) {
            previewControlBar

            let compactPreviewW: CGFloat = CGFloat(110.0 + activeDraft.compactWidthOffset * 0.70)
            let compactPreviewH: CGFloat = max(24, CGFloat(28.0 + activeDraft.compactHeightOffset * 0.85))
            let expandedPreviewW: CGFloat = CGFloat(activeDraft.expandedWidth * 0.52)
            let expandedPreviewH: CGFloat = max(90, CGFloat(112.0 + activeDraft.expandedHeightOffset * 0.55))

            let pWidth: CGFloat = previewExpandedState ? expandedPreviewW : compactPreviewW
            let pHeight: CGFloat = previewExpandedState ? expandedPreviewH : compactPreviewH
            let pWingSlot: CGFloat = max(22, CGFloat(activeDraft.compactWidthOffset * 0.40))
            let pRadius: CGFloat = previewExpandedState
                ? CGFloat(activeDraft.expandedCornerRadius * 0.8)
                : CGFloat(activeDraft.compactCornerRadius * 0.8)
            let pTopEarRadius: CGFloat = previewExpandedState ? 10.0 : 8.0
            let pColor: Color = (activeDraft.waveformColorMode == .monochromeWhite || activeDraft.colorTheme == .monochrome)
                ? .white.opacity(0.85)
                : activeDraft.resolvedColor(for: .mediaAccent(source: mediaManager.currentTrack.source == .none ? .spotify : mediaManager.currentTrack.source))
            let activePreviewSurface = previewExpandedState ? activeDraft.expandedSurfaceStyle : activeDraft.compactSurfaceStyle
            let pStrokeColor: Color = activePreviewSurface == .ambientGlow
                ? pColor.opacity(min(0.6, activeDraft.borderOpacity * 2.2))
                : Color.white.opacity(activeDraft.borderOpacity)
            let previewBatColor: Color = activeDraft.resolvedColor(for: .battery(isLow: false))
            let previewCpuColor: Color = activeDraft.resolvedColor(for: .cpu)
            let previewWeatherPrimary: Color = activeDraft.resolvedColor(for: .weatherPrimary)
            let previewWeatherRain: Color = activeDraft.resolvedColor(for: .weatherPrecipitation)
            let previewCalendarPrimary: Color = activeDraft.resolvedColor(for: .calendarPrimary)
            let previewRamColor: Color = activeDraft.resolvedColor(for: .memory)
            let previewStorageColor: Color = activeDraft.resolvedColor(for: .storage)
            let containerH: CGFloat = previewExpandedState ? max(140, pHeight + 24) : max(66, pHeight + 20)

            // Display Bezel Simulator
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 22/255, green: 22/255, blue: 25/255))

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
                            pColor: pColor,
                            batColor: previewBatColor,
                            cpuColor: previewCpuColor,
                            weatherPrimary: previewWeatherPrimary,
                            weatherRain: previewWeatherRain,
                            calendarPrimary: previewCalendarPrimary,
                            ramColor: previewRamColor,
                            storageColor: previewStorageColor
                        )
                        .frame(width: pWidth, height: pHeight)
                    }
                }
                .background(
                    ZStack {
                        switch activePreviewSurface {
                        case .pitchBlack:
                            Color.black.opacity(activeDraft.notchOpacity)
                        case .liquidGlass:
                            ZStack {
                                Color.white.opacity(0.12)
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.08), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                            .background(.ultraThinMaterial)
                            .opacity(activeDraft.notchOpacity)
                        case .darkGlass:
                            ZStack {
                                Color.black.opacity(0.65)
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.02), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                            .background(.ultraThinMaterial)
                            .opacity(activeDraft.notchOpacity)
                        case .frostedGlass:
                            ZStack {
                                Color(red: 14/255, green: 14/255, blue: 18/255).opacity(0.95)
                                LinearGradient(
                                    colors: [Color.white.opacity(0.05), Color.clear],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            }
                            .opacity(activeDraft.notchOpacity)
                        case .ambientGlow:
                            ZStack {
                                Color.black
                                LinearGradient(
                                    colors: [pColor.opacity(0.22), Color.clear],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            }
                            .opacity(activeDraft.notchOpacity)
                        }

                        if activeDraft.showBorder {
                            UnderNotchBorder(bottomRadius: pRadius, topEarRadius: pTopEarRadius)
                                .stroke(pStrokeColor, lineWidth: CGFloat(activeDraft.borderWidth))
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
            .frame(width: pWingSlot)

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
            .frame(width: pWingSlot)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func previewExpandedNotch(
        draftToUse: ObeliskSettingsDraft,
        currentTab: ObeliskTab,
        pColor: Color,
        batColor: Color,
        cpuColor: Color,
        weatherPrimary: Color,
        weatherRain: Color,
        calendarPrimary: Color,
        ramColor: Color,
        storageColor: Color
    ) -> some View {
        let pTopClearance = CGFloat(max(8, 12.0 + draftToUse.topNotchClearanceOffset * 0.30))
        VStack(spacing: 5) {
            // Header Bar
            HStack {
                HStack(spacing: 4) {
                    ForEach(draftToUse.enabledTabs, id: \.rawValue) { tab in
                        ZStack {
                            Circle()
                                .fill(currentTab == tab ? Color.white.opacity(0.18) : Color.clear)
                                .frame(width: 14, height: 14)
                            Image(systemName: tab.icon)
                                .font(.system(size: 7))
                                .foregroundColor(currentTab == tab ? .white : .white.opacity(0.40))
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, pTopClearance)

            // Active Tab Preview
            switch currentTab {
            case .media:
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(pColor.opacity(0.3))
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 7))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 0.5) {
                                Text(mediaManager.currentTrack.title.isEmpty ? "Paper Sky" : mediaManager.currentTrack.title)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(mediaManager.currentTrack.artist.isEmpty ? "Lumen Coast" : mediaManager.currentTrack.artist)
                                    .font(.system(size: 6.5))
                                    .foregroundColor(.white.opacity(0.45))
                                    .lineLimit(1)
                            }
                        }

                        // Mini progress bar
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 2)
                            .overlay(
                                Capsule().fill(pColor).frame(maxWidth: .infinity, alignment: .leading).frame(width: 35)
                            )

                        HStack(spacing: 8) {
                            Image(systemName: "quote.bubble.fill").font(.system(size: 6.5)).foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Image(systemName: "backward.fill").font(.system(size: 6))
                            Image(systemName: "play.fill").font(.system(size: 7, weight: .bold))
                            Image(systemName: "forward.fill").font(.system(size: 6))
                            Spacer()
                            Image(systemName: "speaker.wave.2.fill").font(.system(size: 6)).foregroundColor(.white.opacity(0.5))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("we fold the summer light")
                            .font(.system(size: 6.5))
                            .foregroundColor(.white.opacity(0.35))
                        Text("into paper birds tonight")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.white)
                        Text("and send them through the sky")
                            .font(.system(size: 6.5))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)

            case .weather:
                HStack(alignment: .center, spacing: 0) {
                    // Hero
                    VStack(alignment: .leading, spacing: 0) {
                        Text(weatherService.weather.cityName.isEmpty ? "South Jakarta" : weatherService.weather.cityName)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)

                        Text("\(draftToUse.convertedTemperature(weatherService.weather.temperature))°")
                            .font(.system(size: 20, weight: .thin))
                            .foregroundColor(.white)

                        Text(weatherService.weather.conditionText.isEmpty ? "Clear" : weatherService.weather.conditionText)
                            .font(.system(size: 6.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))

                        Text("H 32°  L 24°")
                            .font(.system(size: 5.5))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: 58, alignment: .leading)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 38)
                        .padding(.horizontal, 4)

                    // Mini Curve Forecast
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            ForEach(["Now", "15", "16", "17", "18"], id: \.self) { hr in
                                VStack(spacing: 1) {
                                    Image(systemName: "cloud.sun.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(weatherPrimary)
                                    Text(hr)
                                        .font(.system(size: 5))
                                        .foregroundColor(.white.opacity(0.45))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 38)
                        .padding(.horizontal, 4)

                    // Details
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Feels").font(.system(size: 5.5)).foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("31°").font(.system(size: 5.5, weight: .medium)).foregroundColor(.white)
                        }
                        HStack {
                            Text("Rain").font(.system(size: 5.5)).foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("0%").font(.system(size: 5.5, weight: .medium)).foregroundColor(.white)
                        }
                        HStack {
                            Text("Wind").font(.system(size: 5.5)).foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("12 km/h").font(.system(size: 5.5, weight: .medium)).foregroundColor(.white)
                        }
                    }
                    .frame(width: 52, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .brightness((draftToUse.colorBrightness - 1.0) * 0.40)

            case .calendar:
                HStack(alignment: .center, spacing: 0) {
                    // Agenda
                    VStack(alignment: .leading, spacing: 1) {
                        Text("THURSDAY")
                            .font(.system(size: 6, weight: .semibold))
                            .tracking(0.6)
                            .foregroundColor(calendarPrimary)

                        Text("5 November")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.white)

                        Text("No upcoming events today")
                            .font(.system(size: 6))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: 68, alignment: .leading)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 38)
                        .padding(.horizontal, 4)

                    // Mini Month Grid
                    VStack(spacing: 2) {
                        HStack(spacing: 0) {
                            ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { idx, day in
                                Text(day)
                                    .font(.system(size: 5, weight: .medium))
                                    .foregroundColor((idx == 0 || idx == 6) ? Color(red: 1.0, green: 0.32, blue: 0.35) : .white.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        HStack(spacing: 0) {
                            ForEach(1...7, id: \.self) { d in
                                let isToday = (d == 5)
                                let isWeekend = (d == 1 || d == 7)
                                let hasEv = (d == 3 || d == 6)
                                ZStack {
                                    if isToday {
                                        Capsule().fill(Color.white).frame(width: hasEv ? 12 : 9, height: 9)
                                    }
                                    HStack(spacing: 1) {
                                        if hasEv {
                                            Capsule()
                                                .fill(calendarPrimary)
                                                .frame(width: 1, height: 4.5)
                                        }

                                        Text("\(d)")
                                            .font(.system(size: 5.5, weight: isToday ? .bold : .regular))
                                            .foregroundColor(isToday ? .black : (isWeekend ? Color(red: 1.0, green: 0.32, blue: 0.35) : .white.opacity(0.75)))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 10)
                .brightness((draftToUse.colorBrightness - 1.0) * 0.40)

            case .file:
                HStack(spacing: 6) {
                    // Box 1: File Tray
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "tray.full.fill").font(.system(size: 6.5, weight: .bold)).foregroundColor(.green)
                            Text("File Tray").font(.system(size: 6.5, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Text("2").font(.system(size: 5.5, weight: .bold)).foregroundColor(.white.opacity(0.7))
                        }
                        VStack(alignment: .leading, spacing: 1.5) {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.fill").font(.system(size: 5.5)).foregroundColor(.white.opacity(0.6))
                                Text("Spec.pdf").font(.system(size: 5.5)).foregroundColor(.white.opacity(0.8)).lineLimit(1)
                            }
                            HStack(spacing: 2) {
                                Image(systemName: "photo.fill").font(.system(size: 5.5)).foregroundColor(.white.opacity(0.6))
                                Text("Hero.png").font(.system(size: 5.5)).foregroundColor(.white.opacity(0.8)).lineLimit(1)
                            }
                        }
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                    .frame(maxWidth: .infinity)

                    // Box 2: AirDrop
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 6.5, weight: .bold)).foregroundColor(.blue)
                            Text("AirDrop").font(.system(size: 6.5, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Circle().fill(Color.green).frame(width: 3, height: 3)
                        }
                        VStack(spacing: 1.5) {
                            Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 8)).foregroundColor(.blue)
                            Text("Drop to share").font(.system(size: 5.5, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 10)
                .brightness((draftToUse.colorBrightness - 1.0) * 0.40)

            case .notification:
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "bell.badge.fill").font(.system(size: 6.5, weight: .bold)).foregroundColor(Color(red: 52/255, green: 199/255, blue: 89/255))
                            Text("Notifications").font(.system(size: 6.5, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Text("3").font(.system(size: 5.5, weight: .bold)).foregroundColor(.white.opacity(0.7))
                        }
                        VStack(alignment: .leading, spacing: 1.5) {
                            HStack(spacing: 3) {
                                Circle().fill(Color.green).frame(width: 4, height: 4)
                                Text("WhatsApp • Sarah Jenkins").font(.system(size: 5.5, weight: .medium)).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                            }
                            HStack(spacing: 3) {
                                Circle().fill(Color.blue).frame(width: 4, height: 4)
                                Text("Mail • Alexander Satryo").font(.system(size: 5.5, weight: .medium)).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                            }
                        }
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 10)
                .brightness((draftToUse.colorBrightness - 1.0) * 0.40)
            }
        }
        .padding(.bottom, 6)
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

                if isHighlighted {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 5, height: 5)
                }
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

                    Spacer()

                    Text(displayedValueText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        )
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

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.42))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5.5)
            .frame(width: width)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.09), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { isHovered = $0 }
    }
}

/// Modern styled button with subtle rounded corners, micro-interaction hover, and crisp typography
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
                    .font(.system(size: 11.5, weight: isProminent ? .semibold : .medium))
            }
            .foregroundColor(
                isDestructive ? Color.red.opacity(0.92) :
                isProminent ? Color.white :
                Color.white.opacity(0.88)
            )
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .fill(
                        isProminent
                            ? Color.blue.opacity(isHovered ? 0.95 : 0.85)
                            : isDestructive
                                ? Color.red.opacity(isHovered ? 0.16 : 0.08)
                                : Color.white.opacity(isHovered ? 0.12 : 0.07)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .stroke(
                        isProminent
                            ? Color.blue.opacity(0.4)
                            : isDestructive
                                ? Color.red.opacity(0.24)
                                : Color.white.opacity(0.12),
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
            existing.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            existing.level = .floating
            existing.orderFrontRegardless()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
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
        settingsWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        settingsWindow.level = .floating
        settingsWindow.delegate = self
        settingsWindow.center()

        let hosting = NSHostingView(rootView: SettingsView())
        settingsWindow.contentView = hosting

        self.window = settingsWindow
        settingsWindow.orderFrontRegardless()
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
