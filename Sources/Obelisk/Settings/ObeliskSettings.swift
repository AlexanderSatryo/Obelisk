import Foundation
import SwiftUI
import Combine
import ServiceManagement

/// Posted whenever the user toggles the Menu Bar status item visibility in Settings.
public extension Notification.Name {
    static let obeliskMenuBarVisibilityChanged = Notification.Name("obeliskMenuBarVisibilityChanged")
}

// MARK: - Appearance Enums

/// Defines the visual material and surface rendering of the notch container.
public enum NotchSurfaceStyle: String, CaseIterable, Identifiable, Equatable {
    case pitchBlack = "pitchBlack"
    case liquidGlass = "liquidGlass"
    case darkGlass = "darkGlass"
    case frostedGlass = "frostedGlass"
    case ambientGlow = "ambientGlow"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pitchBlack: return "Pitch Black (OLED)"
        case .liquidGlass: return "Liquid Glass"
        case .darkGlass: return "Dark Liquid Glass"
        case .frostedGlass: return "Frosted Dark Glass"
        case .ambientGlow: return "Ambient Source Glow"
        }
    }

    public var subtitle: String {
        switch self {
        case .pitchBlack: return "100% solid black that blends seamlessly into the physical MacBook bezel"
        case .liquidGlass: return "Native Apple Liquid Glass with live refraction of the desktop behind the notch"
        case .darkGlass: return "Native Apple Liquid Glass with a deep dark tint for a calmer look"
        case .frostedGlass: return "Subtle translucent dark surface with elevated inner contrast"
        case .ambientGlow: return "Dynamic accent border and soft inner aura matching the active media source"
        }
    }

    /// Whether this material is rendered by the system Liquid Glass compositor.
    public var isLiquidGlass: Bool {
        self == .liquidGlass || self == .darkGlass
    }
}

/// Controls how the compact notch wings behave when collapsed.
public enum CompactWingMode: String, CaseIterable, Identifiable, Equatable {
    case dynamicAuto = "dynamicAuto"
    case alwaysMinimal = "alwaysMinimal"
    case alwaysWide = "alwaysWide"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dynamicAuto: return "Dynamic Auto (When Media Active)"
        case .alwaysMinimal: return "Always Minimal (Physical Notch Size)"
        case .alwaysWide: return "Always Wide (Persistent Wings)"
        }
    }
}

/// Controls what is displayed inside the Left Wing of the compact notch.
public enum LeftWingContentMode: String, CaseIterable, Identifiable, Equatable {
    case artworkOrLogo = "artworkOrLogo"
    case sourceLogoOnly = "sourceLogoOnly"
    case weatherMini = "weatherMini"
    case batteryStatus = "batteryStatus"
    case cpuLoad = "cpuLoad"
    case hidden = "hidden"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .artworkOrLogo: return "Media Thumbnail / Platform Logo"
        case .sourceLogoOnly: return "Platform Vector Logo Only"
        case .weatherMini: return "Live Weather Icon & Temp"
        case .batteryStatus: return "Live Battery % & Charging Status"
        case .cpuLoad: return "Live CPU Load Percentage"
        case .hidden: return "Hidden"
        }
    }
}

/// Controls the visualizer or indicator rendered inside the Right Wing of the compact notch.
public enum RightWingStyle: String, CaseIterable, Identifiable, Equatable {
    case equalizerBars = "equalizerBars"
    case sineWave = "sineWave"
    case minimalDots = "minimalDots"
    case elapsedTimer = "elapsedTimer"
    case batteryOrPrivacy = "batteryOrPrivacy"
    case systemTelemetry = "systemTelemetry"
    case hidden = "hidden"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .equalizerBars: return "4-Bar Audio Equalizer"
        case .sineWave: return "Fluid Sine Waveform"
        case .minimalDots: return "Minimalist Pulse Dots"
        case .elapsedTimer: return "Live Elapsed Time (mm:ss)"
        case .batteryOrPrivacy: return "Live Battery Percentage"
        case .systemTelemetry: return "Live CPU Load Percentage"
        case .hidden: return "Hidden"
        }
    }
}

/// Controls the color palette of the compact audio visualizer and progress bar.
public enum WaveformColorMode: String, CaseIterable, Identifiable, Equatable {
    case platformAccent = "platformAccent"
    case monochromeWhite = "monochromeWhite"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .platformAccent: return "Dynamic Platform Accent (Spotify / YouTube / Vidio)"
        case .monochromeWhite: return "Minimalist Monochrome White"
        }
    }
}

/// Controls the color palette of the compact elapsed timer when the notch is collapsed.
public enum CompactTimerColorMode: String, CaseIterable, Identifiable, Equatable {
    case followMedia = "followMedia"
    case monochromeWhite = "monochromeWhite"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .followMedia: return "Dynamic Media Color (Spotify, YouTube, Apple Music)"
        case .monochromeWhite: return "Minimalist Monochrome White"
        }
    }
}

/// Defines the global color theme preset applied across the notch.
public enum NotchColorTheme: String, CaseIterable, Identifiable, Equatable {
    case monochrome = "monochrome"
    case colorful = "colorful"
    case soft = "soft"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .monochrome: return "Monochrome"
        case .colorful: return "Colorful"
        case .soft: return "Soft"
        }
    }

    public var subtitle: String {
        switch self {
        case .monochrome: return "Clean, minimal white and cool monochrome gray accents"
        case .colorful: return "Vibrant native Apple System colors (Green, Blue, Purple, Cyan, Red)"
        case .soft: return "Soft, calm pastel tones that are gentle on the eyes"
        }
    }
}

/// Logical color roles across Obelisk UI modules.
public enum NotchColorRole {
    case mediaAccent(source: PlayerSource)
    case cpu
    case memory
    case battery(isLow: Bool)
    case storage
    case weatherPrimary
    case weatherPrecipitation
    case weatherMetric(index: Int)
    case calendarPrimary
}

/// Preset width options for the expanded notch panel.
public enum ExpandedWidthPreset: String, CaseIterable, Identifiable, Equatable {
    case compact = "compact"
    case standard = "standard"
    case wide = "wide"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .compact: return "Compact (560 pt)"
        case .standard: return "Standard (620 pt)"
        case .wide: return "Wide (680 pt)"
        }
    }

    public var width: CGFloat {
        switch self {
        case .compact: return 560
        case .standard: return 620
        case .wide: return 680
        }
    }
}

/// Configures the visual presentation of transient HUD notifications (volume, brightness, charging, earbuds) when the notch is collapsed in standby.
public enum StandbyHUDStyle: String, CaseIterable, Identifiable, Equatable {
    case horizontalWings = "horizontalWings"
    case downwardCard = "downwardCard"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .horizontalWings: return "Horizontal Wings (Side Expansion)"
        case .downwardCard: return "Extended Card (Downward Expansion)"
        }
    }

    public var subtitle: String {
        switch self {
        case .horizontalWings: return "Aligns flush with the menu bar and expands outward to the sides"
        case .downwardCard: return "Expands downward into a pop-out Dynamic Island card"
        }
    }
}

// MARK: - Behavior & Gesture Enums

/// Determines which pointer actions expand the notch.
public enum NotchTriggerMode: String, CaseIterable, Identifiable, Equatable {
    case hoverAndClick = "hoverAndClick"
    case hoverOnly = "hoverOnly"
    case clickOnly = "clickOnly"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hoverAndClick: return "Hover & Click"
        case .hoverOnly: return "Hover Only"
        case .clickOnly: return "Click Only (Disable Auto-Hover)"
        }
    }
}

/// Spring physics speed preset for notch expansion and collapse animations.
public enum AnimationSpeedPreset: String, CaseIterable, Identifiable, Equatable {
    case snappy = "snappy"
    case balanced = "balanced"
    case fluid = "fluid"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .snappy: return "Snappy (0.26s)"
        case .balanced: return "Balanced (0.34s)"
        case .fluid: return "Fluid (0.44s)"
        }
    }

    public var expandResponse: Double {
        switch self {
        case .snappy: return 0.26
        case .balanced: return 0.34
        case .fluid: return 0.44
        }
    }

    public var collapseResponse: Double {
        switch self {
        case .snappy: return 0.24
        case .balanced: return 0.30
        case .fluid: return 0.38
        }
    }
}

// MARK: - Modules & Media Enums

/// Configures which tab is displayed first when the notch expands.
public enum DefaultOpeningTab: String, CaseIterable, Identifiable, Equatable {
    case lastUsed = "lastUsed"
    case alwaysMedia = "alwaysMedia"
    case alwaysWeather = "alwaysWeather"
    case alwaysCalendar = "alwaysCalendar"
    case alwaysFile = "alwaysFile"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .lastUsed: return "Remember Last Opened Tab"
        case .alwaysMedia: return "Always Open Media Player"
        case .alwaysWeather: return "Always Open Weather"
        case .alwaysCalendar: return "Always Open Calendar"
        case .alwaysFile: return "Always Open File Shelf"
        }
    }
}

/// Font scale preset for real-time synchronized lyrics.
public enum LyricsFontSizeScale: String, CaseIterable, Identifiable, Equatable {
    case small = "small"
    case standard = "standard"
    case large = "large"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .small: return "Small"
        case .standard: return "Standard"
        case .large: return "Large"
        }
    }

    public var multiplier: CGFloat {
        switch self {
        case .small: return 0.88
        case .standard: return 1.0
        case .large: return 1.16
        }
    }
}

// MARK: - Weather Enums

/// Temperature measurement unit.
public enum TemperatureUnit: String, CaseIterable, Identifiable, Equatable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .celsius: return "Celsius (°C)"
        case .fahrenheit: return "Fahrenheit (°F)"
        }
    }
}

/// Wind speed measurement unit.
public enum WindSpeedUnit: String, CaseIterable, Identifiable, Equatable {
    case kmh = "kmh"
    case mph = "mph"
    case ms = "ms"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .kmh: return "Kilometers per hour (km/h)"
        case .mph: return "Miles per hour (mph)"
        case .ms: return "Meters per second (m/s)"
        }
    }
}

/// Determines how the weather module resolves geographic coordinates.
public enum WeatherLocationMode: String, CaseIterable, Identifiable, Equatable {
    case deviceGPS = "deviceGPS"
    case manualCity = "manualCity"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .deviceGPS: return "Automatic Device GPS & Network"
        case .manualCity: return "Manual City Override"
        }
    }
}

// MARK: - Staged Settings Draft Model

/// Value-type snapshot of all Obelisk preferences used for staged editing and live previewing in `SettingsView`.
/// Changes made to a draft do not mutate the live notch until explicitly saved via `ObeliskSettings.shared.apply(draft:)`.
public struct ObeliskSettingsDraft: Equatable {
    public var compactSurfaceStyle: NotchSurfaceStyle = .pitchBlack
    public var expandedSurfaceStyle: NotchSurfaceStyle = .liquidGlass
    public var surfaceStyle: NotchSurfaceStyle {
        get { expandedSurfaceStyle }
        set { expandedSurfaceStyle = newValue }
    }
    public var showBorder: Bool = true
    public var borderWidth: Double = 0.8
    public var borderOpacity: Double = 0.12
    public var compactCornerRadius: Double = 14.0
    public var expandedCornerRadius: Double = 18.0
    public var compactTopCornerRadius: Double = 11.0
    public var expandedTopCornerRadius: Double = 14.0
    public var notchOpacity: Double = 1.0
    public var compactWingMode: CompactWingMode = .dynamicAuto
    public var leftWingContent: LeftWingContentMode = .artworkOrLogo
    public var rightWingStyle: RightWingStyle = .equalizerBars
    public var waveformColorMode: WaveformColorMode = .platformAccent
    public var compactTimerColorMode: CompactTimerColorMode = .followMedia
    public var colorTheme: NotchColorTheme = .soft
    public var colorBrightness: Double = 1.0
    public var compactWidthOffset: Double = 112.0
    public var compactHeightOffset: Double = 0.0
    public var standbyHUDStyle: StandbyHUDStyle = .horizontalWings
    public var expandedWidthPreset: ExpandedWidthPreset = .standard
    public var expandedWidth: Double = 620.0
    public var expandedHeightOffset: Double = 0.0
    public var topNotchClearanceOffset: Double = 0.0

    public var triggerMode: NotchTriggerMode = .hoverAndClick
    public var hoverDwellMs: Double = 65.0
    public var exitGraceMs: Double = 180.0
    public var animationSpeed: AnimationSpeedPreset = .balanced
    public var enableHorizontalSwipe: Bool = true
    public var invertHorizontalSwipe: Bool = false
    public var enableVerticalSwipe: Bool = true

    public var enableMediaTab: Bool = true
    public var enableWeatherTab: Bool = true
    public var enableCalendarTab: Bool = true
    public var enableFileTab: Bool = true
    public var showDownloadsOnStandby: Bool = true
    public var enableNotifications: Bool = true
    public var requireTouchIDForNotifications: Bool = true
    public var notificationAutoDismissSeconds: Double = 10.0
    public var enableSystemTab: Bool {
        get { enableFileTab }
        set { enableFileTab = newValue }
    }
    public var defaultOpeningTab: DefaultOpeningTab = .lastUsed

    public var fileTrayCapacity: Int = 10
    public var autoClearAfterAirDrop: Bool = false
    public var showCalendarEventDots: Bool = true

    public var skipIntervalSeconds: Int = 15
    public var showLyricsInNotch: Bool = true
    public var showLyricsButton: Bool = true
    public var autoExpandLyrics: Bool = false
    public var lyricsFontSizeScale: LyricsFontSizeScale = .standard
    public var lyricsSyncOffsetMs: Int = 380

    public var temperatureUnit: TemperatureUnit = .celsius
    public var windSpeedUnit: WindSpeedUnit = .kmh
    public var weatherLocationMode: WeatherLocationMode = .deviceGPS
    public var manualCityName: String = "South Jakarta"
    public var weatherRefreshMinutes: Int = 1

    public var launchAtLogin: Bool = false
    public var showMenuBarIcon: Bool = true

    public init() {}

    public var enabledTabs: [ObeliskTab] {
        var list: [ObeliskTab] = []
        if enableMediaTab { list.append(.media) }
        if enableWeatherTab { list.append(.weather) }
        if enableCalendarTab { list.append(.calendar) }
        if enableFileTab { list.append(.file) }
        if list.isEmpty { list.append(.media) }
        return list
    }

    public func convertedTemperature(_ celsius: Int) -> Int {
        switch temperatureUnit {
        case .celsius:
            return celsius
        case .fahrenheit:
            return Int(round(Double(celsius) * 9.0 / 5.0 + 32.0))
        }
    }

    /// Resets all Appearance properties in this draft back to factory defaults
    public mutating func resetAppearanceToDefaults() {
        resetCategoryToDefaults(.appearance)
    }

    /// Resets preferences of the specified category back to factory defaults
    public mutating func resetCategoryToDefaults(_ category: SettingsCategory) {
        let def = ObeliskSettingsDraft()
        switch category {
        case .appearance:
            self.compactSurfaceStyle = def.compactSurfaceStyle
            self.expandedSurfaceStyle = def.expandedSurfaceStyle
            self.surfaceStyle = def.surfaceStyle
            self.showBorder = def.showBorder
            self.borderWidth = def.borderWidth
            self.borderOpacity = def.borderOpacity
            self.compactCornerRadius = def.compactCornerRadius
            self.expandedCornerRadius = def.expandedCornerRadius
            self.compactTopCornerRadius = def.compactTopCornerRadius
            self.expandedTopCornerRadius = def.expandedTopCornerRadius
            self.notchOpacity = def.notchOpacity
            self.compactWingMode = def.compactWingMode
            self.leftWingContent = def.leftWingContent
            self.rightWingStyle = def.rightWingStyle
            self.waveformColorMode = def.waveformColorMode
            self.compactTimerColorMode = def.compactTimerColorMode
            self.colorTheme = def.colorTheme
            self.colorBrightness = def.colorBrightness
            self.compactWidthOffset = def.compactWidthOffset
            self.compactHeightOffset = def.compactHeightOffset
            self.standbyHUDStyle = def.standbyHUDStyle
            self.expandedWidthPreset = def.expandedWidthPreset
            self.expandedWidth = def.expandedWidth
            self.expandedHeightOffset = def.expandedHeightOffset
            self.topNotchClearanceOffset = def.topNotchClearanceOffset

        case .behavior:
            self.triggerMode = def.triggerMode
            self.hoverDwellMs = def.hoverDwellMs
            self.exitGraceMs = def.exitGraceMs
            self.animationSpeed = def.animationSpeed
            self.enableHorizontalSwipe = def.enableHorizontalSwipe
            self.invertHorizontalSwipe = def.invertHorizontalSwipe
            self.enableVerticalSwipe = def.enableVerticalSwipe

        case .modules:
            self.enableMediaTab = def.enableMediaTab
            self.enableWeatherTab = def.enableWeatherTab
            self.enableCalendarTab = def.enableCalendarTab
            self.enableFileTab = def.enableFileTab
            self.defaultOpeningTab = def.defaultOpeningTab
            self.fileTrayCapacity = def.fileTrayCapacity
            self.autoClearAfterAirDrop = def.autoClearAfterAirDrop
            self.showCalendarEventDots = def.showCalendarEventDots
            self.enableNotifications = def.enableNotifications
            self.requireTouchIDForNotifications = def.requireTouchIDForNotifications
            self.notificationAutoDismissSeconds = def.notificationAutoDismissSeconds

        case .media:
            self.skipIntervalSeconds = def.skipIntervalSeconds
            self.showLyricsInNotch = def.showLyricsInNotch
            self.showLyricsButton = def.showLyricsButton
            self.autoExpandLyrics = def.autoExpandLyrics
            self.lyricsFontSizeScale = def.lyricsFontSizeScale
            self.lyricsSyncOffsetMs = def.lyricsSyncOffsetMs

        case .weather:
            self.temperatureUnit = def.temperatureUnit
            self.windSpeedUnit = def.windSpeedUnit
            self.weatherLocationMode = def.weatherLocationMode
            self.manualCityName = def.manualCityName
            self.weatherRefreshMinutes = def.weatherRefreshMinutes

        case .system:
            self.launchAtLogin = def.launchAtLogin
            self.showMenuBarIcon = def.showMenuBarIcon
        }
    }

    /// Resets all settings across all categories back to factory defaults
    public mutating func resetAllToDefaults() {
        self = ObeliskSettingsDraft()
    }

    /// Resolves dynamic theme color using this draft snapshot
    public func resolvedColor(for role: NotchColorRole) -> Color {
        ObeliskSettings.resolvedColor(for: role, theme: self.colorTheme, brightness: self.colorBrightness)
    }
}

// MARK: - ObeliskSettings Store

/// Centralized reactive preferences store for Obelisk.
/// Persists committed settings to `UserDefaults.standard` and propagates changes to the live notch upon save.
@MainActor
public final class ObeliskSettings: ObservableObject {
    public static let shared = ObeliskSettings()

    private let defaults = UserDefaults.standard

    // MARK: 1. Appearance & Style
    @Published public var compactSurfaceStyle: NotchSurfaceStyle {
        didSet { defaults.set(compactSurfaceStyle.rawValue, forKey: "cfg_compactSurfaceStyle") }
    }
    @Published public var expandedSurfaceStyle: NotchSurfaceStyle {
        didSet {
            defaults.set(expandedSurfaceStyle.rawValue, forKey: "cfg_expandedSurfaceStyle")
            surfaceStyle = expandedSurfaceStyle
        }
    }
    @Published public var surfaceStyle: NotchSurfaceStyle {
        didSet { defaults.set(surfaceStyle.rawValue, forKey: "cfg_surfaceStyle") }
    }
    @Published public var showBorder: Bool {
        didSet { defaults.set(showBorder, forKey: "cfg_showBorder") }
    }
    @Published public var borderWidth: Double {
        didSet { defaults.set(borderWidth, forKey: "cfg_borderWidth") }
    }
    @Published public var borderOpacity: Double {
        didSet { defaults.set(borderOpacity, forKey: "cfg_borderOpacity") }
    }
    @Published public var compactCornerRadius: Double {
        didSet { defaults.set(compactCornerRadius, forKey: "cfg_compactCornerRadius") }
    }
    @Published public var expandedCornerRadius: Double {
        didSet { defaults.set(expandedCornerRadius, forKey: "cfg_expandedCornerRadius") }
    }
    @Published public var compactTopCornerRadius: Double {
        didSet { defaults.set(compactTopCornerRadius, forKey: "cfg_compactTopCornerRadius") }
    }
    @Published public var expandedTopCornerRadius: Double {
        didSet { defaults.set(expandedTopCornerRadius, forKey: "cfg_expandedTopCornerRadius") }
    }
    @Published public var notchOpacity: Double {
        didSet { defaults.set(notchOpacity, forKey: "cfg_notchOpacity") }
    }
    @Published public var compactWingMode: CompactWingMode {
        didSet {
            defaults.set(compactWingMode.rawValue, forKey: "cfg_compactWingMode")
            WindowManager.shared.updateCompactWidth(animated: true)
        }
    }
    @Published public var leftWingContent: LeftWingContentMode {
        didSet {
            defaults.set(leftWingContent.rawValue, forKey: "cfg_leftWingContent")
            WindowManager.shared.updateCompactWidth(animated: true)
        }
    }
    @Published public var rightWingStyle: RightWingStyle {
        didSet {
            defaults.set(rightWingStyle.rawValue, forKey: "cfg_rightWingStyle")
            WindowManager.shared.updateCompactWidth(animated: true)
        }
    }
    @Published public var waveformColorMode: WaveformColorMode {
        didSet { defaults.set(waveformColorMode.rawValue, forKey: "cfg_waveformColorMode") }
    }
    @Published public var compactTimerColorMode: CompactTimerColorMode {
        didSet { defaults.set(compactTimerColorMode.rawValue, forKey: "cfg_compactTimerColorMode") }
    }
    @Published public var colorTheme: NotchColorTheme {
        didSet { defaults.set(colorTheme.rawValue, forKey: "cfg_colorTheme") }
    }
    @Published public var colorBrightness: Double {
        didSet { defaults.set(colorBrightness, forKey: "cfg_colorBrightness") }
    }
    @Published public var compactWidthOffset: Double {
        didSet {
            defaults.set(compactWidthOffset, forKey: "cfg_compactWidthOffset")
            WindowManager.shared.updateCompactWidth(animated: true)
        }
    }
    @Published public var compactHeightOffset: Double {
        didSet {
            defaults.set(compactHeightOffset, forKey: "cfg_compactHeightOffset")
            WindowManager.shared.updateCompactWidth(animated: true)
        }
    }
    @Published public var standbyHUDStyle: StandbyHUDStyle {
        didSet {
            defaults.set(standbyHUDStyle.rawValue, forKey: "cfg_standbyHUDStyle")
            WindowManager.shared.updateCompactWidth(animated: true)
        }
    }
    @Published public var expandedWidthPreset: ExpandedWidthPreset {
        didSet {
            defaults.set(expandedWidthPreset.rawValue, forKey: "cfg_expandedWidthPreset")
            WindowManager.shared.updateHeightForCurrentTab()
        }
    }
    @Published public var expandedWidth: Double {
        didSet {
            defaults.set(expandedWidth, forKey: "cfg_expandedWidth")
            WindowManager.shared.updateHeightForCurrentTab()
        }
    }
    @Published public var expandedHeightOffset: Double {
        didSet {
            defaults.set(expandedHeightOffset, forKey: "cfg_expandedHeightOffset")
            WindowManager.shared.updateHeightForCurrentTab()
        }
    }
    @Published public var topNotchClearanceOffset: Double {
        didSet {
            defaults.set(topNotchClearanceOffset, forKey: "cfg_topNotchClearanceOffset")
            WindowManager.shared.updateHeightForCurrentTab()
        }
    }

    // MARK: 2. Behavior & Gestures
    @Published public var triggerMode: NotchTriggerMode {
        didSet { defaults.set(triggerMode.rawValue, forKey: "cfg_triggerMode") }
    }
    @Published public var hoverDwellMs: Double {
        didSet { defaults.set(hoverDwellMs, forKey: "cfg_hoverDwellMs") }
    }
    @Published public var exitGraceMs: Double {
        didSet { defaults.set(exitGraceMs, forKey: "cfg_exitGraceMs") }
    }
    @Published public var animationSpeed: AnimationSpeedPreset {
        didSet { defaults.set(animationSpeed.rawValue, forKey: "cfg_animationSpeed") }
    }
    @Published public var enableHorizontalSwipe: Bool {
        didSet { defaults.set(enableHorizontalSwipe, forKey: "cfg_enableHorizontalSwipe") }
    }
    @Published public var invertHorizontalSwipe: Bool {
        didSet { defaults.set(invertHorizontalSwipe, forKey: "cfg_invertHorizontalSwipe") }
    }
    @Published public var enableVerticalSwipe: Bool {
        didSet { defaults.set(enableVerticalSwipe, forKey: "cfg_enableVerticalSwipe") }
    }

    // MARK: 3. Modules & Tabs
    @Published public var enableMediaTab: Bool {
        didSet {
            defaults.set(enableMediaTab, forKey: "cfg_enableMediaTab")
            WindowManager.shared.ensureValidCurrentTab()
        }
    }
    @Published public var enableWeatherTab: Bool {
        didSet {
            defaults.set(enableWeatherTab, forKey: "cfg_enableWeatherTab")
            WindowManager.shared.ensureValidCurrentTab()
        }
    }
    @Published public var enableCalendarTab: Bool {
        didSet {
            defaults.set(enableCalendarTab, forKey: "cfg_enableCalendarTab")
            WindowManager.shared.ensureValidCurrentTab()
        }
    }
    @Published public var enableFileTab: Bool {
        didSet {
            defaults.set(enableFileTab, forKey: "cfg_enableFileTab")
            WindowManager.shared.ensureValidCurrentTab()
        }
    }
    @Published public var showDownloadsOnStandby: Bool {
        didSet { defaults.set(showDownloadsOnStandby, forKey: "cfg_showDownloadsOnStandby") }
    }
    @Published public var enableNotifications: Bool {
        didSet { defaults.set(enableNotifications, forKey: "cfg_enableNotifications") }
    }
    @Published public var requireTouchIDForNotifications: Bool {
        didSet { defaults.set(requireTouchIDForNotifications, forKey: "cfg_requireTouchIDForNotifications") }
    }
    @Published public var notificationAutoDismissSeconds: Double {
        didSet { defaults.set(notificationAutoDismissSeconds, forKey: "cfg_notificationAutoDismissSeconds") }
    }
    public var enableSystemTab: Bool {
        get { enableFileTab }
        set { enableFileTab = newValue }
    }
    @Published public var defaultOpeningTab: DefaultOpeningTab {
        didSet { defaults.set(defaultOpeningTab.rawValue, forKey: "cfg_defaultOpeningTab") }
    }
    @Published public var fileTrayCapacity: Int {
        didSet { defaults.set(fileTrayCapacity, forKey: "cfg_fileTrayCapacity") }
    }
    @Published public var autoClearAfterAirDrop: Bool {
        didSet { defaults.set(autoClearAfterAirDrop, forKey: "cfg_autoClearAfterAirDrop") }
    }
    @Published public var showCalendarEventDots: Bool {
        didSet { defaults.set(showCalendarEventDots, forKey: "cfg_showCalendarEventDots") }
    }
    @Published public var lastActiveTab: ObeliskTab {
        didSet { defaults.set(lastActiveTab.rawValue, forKey: "cfg_lastActiveTab") }
    }

    // MARK: 4. Media & Lyrics
    @Published public var skipIntervalSeconds: Int {
        didSet { defaults.set(skipIntervalSeconds, forKey: "cfg_skipIntervalSeconds") }
    }
    @Published public var showLyricsInNotch: Bool {
        didSet {
            defaults.set(showLyricsInNotch, forKey: "cfg_showLyricsInNotch")
            WindowManager.shared.updateHeightForCurrentTab()
        }
    }
    @Published public var showLyricsButton: Bool {
        didSet { defaults.set(showLyricsButton, forKey: "cfg_showLyricsButton") }
    }
    @Published public var autoExpandLyrics: Bool {
        didSet {
            defaults.set(autoExpandLyrics, forKey: "cfg_autoExpandLyrics")
            if autoExpandLyrics {
                LyricsService.shared.isLyricsExpanded = true
                WindowManager.shared.updateHeightForCurrentTab()
            }
        }
    }
    @Published public var lyricsFontSizeScale: LyricsFontSizeScale {
        didSet { defaults.set(lyricsFontSizeScale.rawValue, forKey: "cfg_lyricsFontSizeScale") }
    }
    @Published public var lyricsSyncOffsetMs: Int {
        didSet { defaults.set(lyricsSyncOffsetMs, forKey: "cfg_lyricsSyncOffsetMs") }
    }

    // MARK: 5. Weather & Units
    @Published public var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: "cfg_temperatureUnit") }
    }
    @Published public var windSpeedUnit: WindSpeedUnit {
        didSet { defaults.set(windSpeedUnit.rawValue, forKey: "cfg_windSpeedUnit") }
    }
    @Published public var weatherLocationMode: WeatherLocationMode {
        didSet {
            defaults.set(weatherLocationMode.rawValue, forKey: "cfg_weatherLocationMode")
            WeatherService.shared.refreshForSettingsChange()
        }
    }
    @Published public var manualCityName: String {
        didSet {
            defaults.set(manualCityName, forKey: "cfg_manualCityName")
        }
    }
    @Published public var weatherRefreshMinutes: Int {
        didSet {
            defaults.set(weatherRefreshMinutes, forKey: "cfg_weatherRefreshMinutes")
            WeatherService.shared.restartPeriodicRefresh()
        }
    }

    // MARK: 6. System & General
    @Published public var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "cfg_launchAtLogin")
            updateLaunchAtLoginState(launchAtLogin)
        }
    }
    @Published public var showMenuBarIcon: Bool {
        didSet {
            defaults.set(showMenuBarIcon, forKey: "cfg_showMenuBarIcon")
            NotificationCenter.default.post(name: .obeliskMenuBarVisibilityChanged, object: nil)
        }
    }

    // MARK: Initialization

    private init() {
        let legacySurface = NotchSurfaceStyle(rawValue: defaults.string(forKey: "cfg_surfaceStyle") ?? "")
        let compStyle = NotchSurfaceStyle(rawValue: defaults.string(forKey: "cfg_compactSurfaceStyle") ?? "") ?? .pitchBlack
        let expStyle = NotchSurfaceStyle(rawValue: defaults.string(forKey: "cfg_expandedSurfaceStyle") ?? "") ?? legacySurface ?? .liquidGlass
        self.compactSurfaceStyle = compStyle
        self.expandedSurfaceStyle = expStyle
        self.surfaceStyle = expStyle
        self.showBorder = defaults.object(forKey: "cfg_showBorder") as? Bool ?? true
        self.borderWidth = defaults.object(forKey: "cfg_borderWidth") as? Double ?? 0.8
        self.borderOpacity = defaults.object(forKey: "cfg_borderOpacity") as? Double ?? 0.12
        self.compactCornerRadius = defaults.object(forKey: "cfg_compactCornerRadius") as? Double ?? 14.0
        self.expandedCornerRadius = defaults.object(forKey: "cfg_expandedCornerRadius") as? Double ?? 18.0
        self.compactTopCornerRadius = defaults.object(forKey: "cfg_compactTopCornerRadius") as? Double ?? 11.0
        self.expandedTopCornerRadius = defaults.object(forKey: "cfg_expandedTopCornerRadius") as? Double ?? 14.0
        self.notchOpacity = defaults.object(forKey: "cfg_notchOpacity") as? Double ?? 1.0
        self.compactWingMode = CompactWingMode(rawValue: defaults.string(forKey: "cfg_compactWingMode") ?? "") ?? .dynamicAuto
        self.leftWingContent = LeftWingContentMode(rawValue: defaults.string(forKey: "cfg_leftWingContent") ?? "") ?? .artworkOrLogo
        self.rightWingStyle = RightWingStyle(rawValue: defaults.string(forKey: "cfg_rightWingStyle") ?? "") ?? .equalizerBars
        self.waveformColorMode = WaveformColorMode(rawValue: defaults.string(forKey: "cfg_waveformColorMode") ?? "") ?? .platformAccent
        self.compactTimerColorMode = CompactTimerColorMode(rawValue: defaults.string(forKey: "cfg_compactTimerColorMode") ?? "") ?? .followMedia
        self.colorTheme = NotchColorTheme(rawValue: defaults.string(forKey: "cfg_colorTheme") ?? "") ?? .soft
        self.colorBrightness = defaults.object(forKey: "cfg_colorBrightness") as? Double ?? 1.0
        self.compactWidthOffset = defaults.object(forKey: "cfg_compactWidthOffset") as? Double ?? 112.0
        self.compactHeightOffset = defaults.object(forKey: "cfg_compactHeightOffset") as? Double ?? 0.0
        self.standbyHUDStyle = StandbyHUDStyle(rawValue: defaults.string(forKey: "cfg_standbyHUDStyle") ?? "") ?? .horizontalWings
        let preset = ExpandedWidthPreset(rawValue: defaults.string(forKey: "cfg_expandedWidthPreset") ?? "") ?? .standard
        self.expandedWidthPreset = preset
        // Older builds stored widths below 560 pt, which are too narrow for the current page layouts.
        let loadedWidth = defaults.object(forKey: "cfg_expandedWidth") as? Double ?? Double(preset.width)
        self.expandedWidth = loadedWidth < 560.0 ? Double(max(preset.width, 620)) : loadedWidth
        self.expandedHeightOffset = defaults.object(forKey: "cfg_expandedHeightOffset") as? Double ?? 0.0
        self.topNotchClearanceOffset = defaults.object(forKey: "cfg_topNotchClearanceOffset") as? Double ?? 0.0

        self.triggerMode = NotchTriggerMode(rawValue: defaults.string(forKey: "cfg_triggerMode") ?? "") ?? .hoverAndClick
        self.hoverDwellMs = defaults.object(forKey: "cfg_hoverDwellMs") as? Double ?? 65.0
        self.exitGraceMs = defaults.object(forKey: "cfg_exitGraceMs") as? Double ?? 180.0
        self.animationSpeed = AnimationSpeedPreset(rawValue: defaults.string(forKey: "cfg_animationSpeed") ?? "") ?? .balanced
        self.enableHorizontalSwipe = defaults.object(forKey: "cfg_enableHorizontalSwipe") as? Bool ?? true
        self.invertHorizontalSwipe = defaults.object(forKey: "cfg_invertHorizontalSwipe") as? Bool ?? false
        self.enableVerticalSwipe = defaults.object(forKey: "cfg_enableVerticalSwipe") as? Bool ?? true

        self.enableMediaTab = defaults.object(forKey: "cfg_enableMediaTab") as? Bool ?? true
        self.enableWeatherTab = defaults.object(forKey: "cfg_enableWeatherTab") as? Bool ?? true
        self.enableCalendarTab = defaults.object(forKey: "cfg_enableCalendarTab") as? Bool ?? true
        self.enableFileTab = defaults.object(forKey: "cfg_enableFileTab") as? Bool ?? (defaults.object(forKey: "cfg_enableSystemTab") as? Bool ?? true)
        self.showDownloadsOnStandby = defaults.object(forKey: "cfg_showDownloadsOnStandby") as? Bool ?? true
        self.enableNotifications = defaults.object(forKey: "cfg_enableNotifications") as? Bool ?? true
        self.requireTouchIDForNotifications = defaults.object(forKey: "cfg_requireTouchIDForNotifications") as? Bool ?? true
        self.notificationAutoDismissSeconds = defaults.object(forKey: "cfg_notificationAutoDismissSeconds") as? Double ?? 10.0
        let savedDefaultTabRaw = defaults.string(forKey: "cfg_defaultOpeningTab") ?? ""
        if savedDefaultTabRaw == "alwaysSystem" {
            self.defaultOpeningTab = .alwaysFile
        } else {
            self.defaultOpeningTab = DefaultOpeningTab(rawValue: savedDefaultTabRaw) ?? .lastUsed
        }
        self.fileTrayCapacity = defaults.object(forKey: "cfg_fileTrayCapacity") as? Int ?? 10
        self.autoClearAfterAirDrop = defaults.object(forKey: "cfg_autoClearAfterAirDrop") as? Bool ?? false
        self.showCalendarEventDots = defaults.object(forKey: "cfg_showCalendarEventDots") as? Bool ?? true
        let savedTabRaw = defaults.object(forKey: "cfg_lastActiveTab") as? Int ?? 0
        self.lastActiveTab = ObeliskTab(rawValue: savedTabRaw) ?? .media

        self.skipIntervalSeconds = defaults.object(forKey: "cfg_skipIntervalSeconds") as? Int ?? 15
        self.showLyricsInNotch = defaults.object(forKey: "cfg_showLyricsInNotch") as? Bool ?? true
        self.showLyricsButton = defaults.object(forKey: "cfg_showLyricsButton") as? Bool ?? true
        self.autoExpandLyrics = defaults.object(forKey: "cfg_autoExpandLyrics") as? Bool ?? false
        self.lyricsFontSizeScale = LyricsFontSizeScale(rawValue: defaults.string(forKey: "cfg_lyricsFontSizeScale") ?? "") ?? .standard
        self.lyricsSyncOffsetMs = defaults.object(forKey: "cfg_lyricsSyncOffsetMs") as? Int ?? 380

        self.temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: "cfg_temperatureUnit") ?? "") ?? .celsius
        self.windSpeedUnit = WindSpeedUnit(rawValue: defaults.string(forKey: "cfg_windSpeedUnit") ?? "") ?? .kmh
        self.weatherLocationMode = WeatherLocationMode(rawValue: defaults.string(forKey: "cfg_weatherLocationMode") ?? "") ?? .deviceGPS
        self.manualCityName = defaults.string(forKey: "cfg_manualCityName") ?? "South Jakarta"
        self.weatherRefreshMinutes = defaults.object(forKey: "cfg_weatherRefreshMinutes") as? Int ?? 1

        self.launchAtLogin = defaults.object(forKey: "cfg_launchAtLogin") as? Bool ?? false
        self.showMenuBarIcon = defaults.object(forKey: "cfg_showMenuBarIcon") as? Bool ?? true
    }

    // MARK: - Draft Creation & Explicit Save

    /// Creates a value-type snapshot of the currently active settings for staged editing in `SettingsView`.
    public func makeDraft() -> ObeliskSettingsDraft {
        var d = ObeliskSettingsDraft()
        d.compactSurfaceStyle = compactSurfaceStyle
        d.expandedSurfaceStyle = expandedSurfaceStyle
        d.surfaceStyle = expandedSurfaceStyle
        d.showBorder = showBorder
        d.borderWidth = borderWidth
        d.borderOpacity = borderOpacity
        d.compactCornerRadius = compactCornerRadius
        d.expandedCornerRadius = expandedCornerRadius
        d.compactTopCornerRadius = compactTopCornerRadius
        d.expandedTopCornerRadius = expandedTopCornerRadius
        d.notchOpacity = notchOpacity
        d.compactWingMode = compactWingMode
        d.leftWingContent = leftWingContent
        d.rightWingStyle = rightWingStyle
        d.waveformColorMode = waveformColorMode
        d.compactTimerColorMode = compactTimerColorMode
        d.colorTheme = colorTheme
        d.colorBrightness = colorBrightness
        d.compactWidthOffset = compactWidthOffset
        d.compactHeightOffset = compactHeightOffset
        d.standbyHUDStyle = standbyHUDStyle
        d.expandedWidthPreset = expandedWidthPreset
        d.expandedWidth = expandedWidth
        d.expandedHeightOffset = expandedHeightOffset
        d.topNotchClearanceOffset = topNotchClearanceOffset

        d.triggerMode = triggerMode
        d.hoverDwellMs = hoverDwellMs
        d.exitGraceMs = exitGraceMs
        d.animationSpeed = animationSpeed
        d.enableHorizontalSwipe = enableHorizontalSwipe
        d.invertHorizontalSwipe = invertHorizontalSwipe
        d.enableVerticalSwipe = enableVerticalSwipe

        d.enableMediaTab = enableMediaTab
        d.enableWeatherTab = enableWeatherTab
        d.enableCalendarTab = enableCalendarTab
        d.enableFileTab = enableFileTab
        d.showDownloadsOnStandby = showDownloadsOnStandby
        d.enableNotifications = enableNotifications
        d.requireTouchIDForNotifications = requireTouchIDForNotifications
        d.notificationAutoDismissSeconds = notificationAutoDismissSeconds
        d.defaultOpeningTab = defaultOpeningTab
        d.fileTrayCapacity = fileTrayCapacity
        d.autoClearAfterAirDrop = autoClearAfterAirDrop
        d.showCalendarEventDots = showCalendarEventDots

        d.skipIntervalSeconds = skipIntervalSeconds
        d.showLyricsInNotch = showLyricsInNotch
        d.showLyricsButton = showLyricsButton
        d.autoExpandLyrics = autoExpandLyrics
        d.lyricsFontSizeScale = lyricsFontSizeScale
        d.lyricsSyncOffsetMs = lyricsSyncOffsetMs

        d.temperatureUnit = temperatureUnit
        d.windSpeedUnit = windSpeedUnit
        d.weatherLocationMode = weatherLocationMode
        d.manualCityName = manualCityName
        d.weatherRefreshMinutes = weatherRefreshMinutes

        d.launchAtLogin = launchAtLogin
        d.showMenuBarIcon = showMenuBarIcon
        return d
    }

    /// Commits a staged `ObeliskSettingsDraft` to the live notch and persists all changes to `UserDefaults`.
    public func apply(draft: ObeliskSettingsDraft) {
        let cityChanged = (manualCityName != draft.manualCityName || weatherLocationMode != draft.weatherLocationMode)

        compactSurfaceStyle = draft.compactSurfaceStyle
        expandedSurfaceStyle = draft.expandedSurfaceStyle
        surfaceStyle = draft.expandedSurfaceStyle
        showBorder = draft.showBorder
        borderWidth = draft.borderWidth
        borderOpacity = draft.borderOpacity
        compactCornerRadius = draft.compactCornerRadius
        expandedCornerRadius = draft.expandedCornerRadius
        compactTopCornerRadius = draft.compactTopCornerRadius
        expandedTopCornerRadius = draft.expandedTopCornerRadius
        notchOpacity = draft.notchOpacity
        compactWingMode = draft.compactWingMode
        leftWingContent = draft.leftWingContent
        rightWingStyle = draft.rightWingStyle
        waveformColorMode = draft.waveformColorMode
        compactTimerColorMode = draft.compactTimerColorMode
        colorTheme = draft.colorTheme
        colorBrightness = draft.colorBrightness
        compactWidthOffset = draft.compactWidthOffset
        compactHeightOffset = draft.compactHeightOffset
        standbyHUDStyle = draft.standbyHUDStyle
        expandedWidthPreset = draft.expandedWidthPreset
        expandedWidth = draft.expandedWidth
        expandedHeightOffset = draft.expandedHeightOffset
        topNotchClearanceOffset = draft.topNotchClearanceOffset

        triggerMode = draft.triggerMode
        hoverDwellMs = draft.hoverDwellMs
        exitGraceMs = draft.exitGraceMs
        animationSpeed = draft.animationSpeed
        enableHorizontalSwipe = draft.enableHorizontalSwipe
        invertHorizontalSwipe = draft.invertHorizontalSwipe
        enableVerticalSwipe = draft.enableVerticalSwipe

        enableMediaTab = draft.enableMediaTab
        enableWeatherTab = draft.enableWeatherTab
        enableCalendarTab = draft.enableCalendarTab
        enableFileTab = draft.enableFileTab
        showDownloadsOnStandby = draft.showDownloadsOnStandby
        enableNotifications = draft.enableNotifications
        requireTouchIDForNotifications = draft.requireTouchIDForNotifications
        notificationAutoDismissSeconds = draft.notificationAutoDismissSeconds
        defaultOpeningTab = draft.defaultOpeningTab
        fileTrayCapacity = draft.fileTrayCapacity
        autoClearAfterAirDrop = draft.autoClearAfterAirDrop
        showCalendarEventDots = draft.showCalendarEventDots

        skipIntervalSeconds = draft.skipIntervalSeconds
        showLyricsInNotch = draft.showLyricsInNotch
        showLyricsButton = draft.showLyricsButton
        autoExpandLyrics = draft.autoExpandLyrics
        lyricsFontSizeScale = draft.lyricsFontSizeScale
        lyricsSyncOffsetMs = draft.lyricsSyncOffsetMs

        temperatureUnit = draft.temperatureUnit
        windSpeedUnit = draft.windSpeedUnit
        manualCityName = draft.manualCityName
        weatherLocationMode = draft.weatherLocationMode
        weatherRefreshMinutes = draft.weatherRefreshMinutes

        launchAtLogin = draft.launchAtLogin
        showMenuBarIcon = draft.showMenuBarIcon

        if cityChanged {
            WeatherService.shared.refreshForSettingsChange()
        }
        WindowManager.shared.updateCompactWidth(animated: true)
        WindowManager.shared.updateHeightForCurrentTab()
    }

    // MARK: - Helper Computed Properties & Formatters

    /// Returns the list of currently enabled dashboard tabs, guaranteeing at least `.media` is available.
    public var enabledTabs: [ObeliskTab] {
        var list: [ObeliskTab] = []
        if enableMediaTab { list.append(.media) }
        if enableWeatherTab { list.append(.weather) }
        if enableCalendarTab { list.append(.calendar) }
        if enableFileTab { list.append(.file) }
        if list.isEmpty { list.append(.media) }
        return list
    }

    /// Converts a Celsius integer temperature into the user's selected unit value.
    public func convertedTemperature(_ celsius: Int) -> Int {
        switch temperatureUnit {
        case .celsius:
            return celsius
        case .fahrenheit:
            return Int(round(Double(celsius) * 9.0 / 5.0 + 32.0))
        }
    }

    /// Formats a wind speed value given in km/h into the user's selected unit string.
    public func formattedWindSpeed(_ kmh: Int) -> String {
        switch windSpeedUnit {
        case .kmh:
            return "\(kmh) km/h"
        case .mph:
            let mph = Int(round(Double(kmh) * 0.621371))
            return "\(mph) mph"
        case .ms:
            let ms = String(format: "%.1f", Double(kmh) / 3.6)
            return "\(ms) m/s"
        }
    }

    // MARK: - Dynamic Theme Color Engine & Brightness Customization

    /// Resolves theme-aware accent colors across Obelisk UI modules with custom brightness
    public func resolvedColor(
        for role: NotchColorRole,
        theme: NotchColorTheme? = nil,
        brightness: Double? = nil
    ) -> Color {
        Self.resolvedColor(
            for: role,
            theme: theme ?? self.colorTheme,
            brightness: brightness ?? self.colorBrightness
        )
    }

    /// Static non-isolated theme color resolver
    public nonisolated static func resolvedColor(
        for role: NotchColorRole,
        theme: NotchColorTheme,
        brightness: Double
    ) -> Color {
        let rawColor: Color

        switch theme {
        case .monochrome:
            switch role {
            case .mediaAccent:
                rawColor = Color.white.opacity(0.92)
            case .cpu:
                rawColor = Color.white.opacity(0.85)
            case .memory:
                rawColor = Color.white.opacity(0.78)
            case .battery(let isLow):
                rawColor = isLow ? Color.white.opacity(0.55) : Color.white.opacity(0.90)
            case .storage:
                rawColor = Color.white.opacity(0.72)
            case .weatherPrimary:
                rawColor = Color.white.opacity(0.90)
            case .weatherPrecipitation:
                rawColor = Color.white.opacity(0.75)
            case .weatherMetric:
                rawColor = Color.white.opacity(0.80)
            case .calendarPrimary:
                rawColor = Color.white.opacity(0.88)
            }

        case .colorful:
            switch role {
            case .mediaAccent(let source):
                switch source {
                case .youtube: rawColor = Color.red
                case .vidio: rawColor = Color(red: 237/255, green: 30/255, blue: 71/255)
                case .spotify: rawColor = Color.green
                case .appleMusic: rawColor = Color.pink
                case .bein: rawColor = Color.purple
                default: rawColor = Color.green
                }
            case .cpu:
                rawColor = Color.blue
            case .memory:
                rawColor = Color.purple
            case .battery(let isLow):
                rawColor = isLow ? Color.orange : Color.green
            case .storage:
                rawColor = Color.cyan
            case .weatherPrimary:
                rawColor = Color.blue
            case .weatherPrecipitation:
                rawColor = Color.cyan
            case .weatherMetric(let idx):
                switch idx {
                case 0: rawColor = Color.blue
                case 1: rawColor = Color.teal
                case 2: rawColor = Color.orange
                case 3: rawColor = Color.indigo
                default: rawColor = Color.cyan
                }
            case .calendarPrimary:
                rawColor = Color.red
            }

        case .soft:
            switch role {
            case .mediaAccent(let source):
                switch source {
                case .youtube: rawColor = Color(red: 215/255, green: 115/255, blue: 115/255)
                case .vidio: rawColor = Color(red: 210/255, green: 110/255, blue: 130/255)
                case .spotify: rawColor = Color(red: 110/255, green: 182/255, blue: 138/255)
                case .appleMusic: rawColor = Color(red: 215/255, green: 130/255, blue: 155/255)
                case .bein: rawColor = Color(red: 165/255, green: 140/255, blue: 195/255)
                default: rawColor = Color(red: 110/255, green: 182/255, blue: 138/255)
                }
            case .cpu:
                rawColor = Color(red: 112/255, green: 168/255, blue: 198/255)
            case .memory:
                rawColor = Color(red: 158/255, green: 134/255, blue: 194/255)
            case .battery(let isLow):
                rawColor = isLow ? Color(red: 212/255, green: 164/255, blue: 98/255) : Color(red: 110/255, green: 182/255, blue: 138/255)
            case .storage:
                rawColor = Color(red: 124/255, green: 158/255, blue: 196/255)
            case .weatherPrimary:
                rawColor = Color(red: 112/255, green: 168/255, blue: 198/255)
            case .weatherPrecipitation:
                rawColor = Color(red: 124/255, green: 178/255, blue: 206/255)
            case .weatherMetric(let idx):
                switch idx {
                case 0: rawColor = Color(red: 112/255, green: 168/255, blue: 198/255)
                case 1: rawColor = Color(red: 110/255, green: 182/255, blue: 138/255)
                case 2: rawColor = Color(red: 212/255, green: 164/255, blue: 98/255)
                case 3: rawColor = Color(red: 158/255, green: 134/255, blue: 194/255)
                default: rawColor = Color(red: 112/255, green: 168/255, blue: 198/255)
                }
            case .calendarPrimary:
                rawColor = Color(red: 215/255, green: 115/255, blue: 115/255)
            }
        }

        return ObeliskSettings.adjustBrightness(of: rawColor, factor: brightness)
    }

    /// Dynamically scales color brightness and vibrancy
    public nonisolated static func adjustBrightness(of color: Color, factor: Double) -> Color {
        guard abs(factor - 1.0) > 0.01 else { return color }
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if s < 0.05 {
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
            ns.getRed(&r, green: &g, blue: &bl, alpha: &a)
            let adjR = min(1.0, max(0.1, r * CGFloat(factor)))
            let adjG = min(1.0, max(0.1, g * CGFloat(factor)))
            let adjB = min(1.0, max(0.1, bl * CGFloat(factor)))
            return Color(nsColor: NSColor(red: adjR, green: adjG, blue: adjB, alpha: a))
        }
        let newB = min(1.0, max(0.15, b * CGFloat(factor)))
        let newS = factor > 1.0 ? max(0.15, s - CGFloat((factor - 1.0) * 0.35)) : s
        return Color(nsColor: NSColor(hue: h, saturation: newS, brightness: newB, alpha: a))
    }

    /// Resets all preferences back to their factory defaults.
    public func resetAllToDefaults() {
        apply(draft: ObeliskSettingsDraft())
    }

    private func updateLaunchAtLoginState(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {}
        }
    }
}
