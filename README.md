# Obelisk — Native Dynamic Island for macOS

Obelisk is a native macOS utility built with Swift and SwiftUI for Apple Silicon MacBook models equipped with a physical display notch (including MacBook Pro M-series). It transforms the top bezel camera housing into an interactive, GPU-accelerated Dynamic Island with real-time media playback telemetry, millisecond-synchronized lyrics, live meteorological forecasts, native Apple Calendar integration, and a comprehensive customization engine.

---

## Key Capabilities

1. **Hardware-Matched Notch Morphing**
   - Automatically queries `NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea` to match the exact physical notch dimensions (`185 x 32 pt` on MacBook Pro M5).
   - Uses a single unified `NotchShape` container inside a fixed transparent canvas so expansion and collapse animations run at 120Hz on the GPU without WindowServer frame-resize stutter.
   - Mathematical screen-coordinate pointer tracking (`NSEvent.mouseLocation`) eliminates false SwiftUI `.onHover` exit loops.

2. **Universal Real-Time Media & Artwork Integration**
   - Powered by a persistent Apple-signed `/usr/bin/swift` MediaRemote XPC sidecar (`MediaRemoteBridge.swift`) that bypasses macOS 15.4+ / Tahoe `mediaremoted` entitlement restrictions.
   - Streams sub-second `calculatedPlaybackPosition`, duration, playback state, and 600x600 native artwork buffers for **Spotify**, **Apple Music**, **YouTube**, **Vidio**, and **beIN Sports** across Safari, Google Chrome, Brave, Arc, and Edge.
   - Interactive scrubbable progress bar and configurable video skip controls (`5s`, `10s`, `15s`, `30s`).

3. **Real-Time Synchronized Lyrics**
   - Queries the LRCLIB API for time-synced `.lrc` lyrics matching the active track.
   - Provides both a compact 2-line preview and an expandable, click-to-seek karaoke scroll view.

4. **Live Weather & Hourly Telemetry**
   - Combines `CoreLocation` GPS coordinates, IP geolocation fallback, and Open-Meteo real-time meteorological telemetry.
   - Displays current temperature, condition icon, daily high/low, feels-like temperature, 5-hour forecast, and an expandable metrics drawer (Humidity, Wind Speed & Direction, UV Index, Surface Pressure).

5. **Native Apple Calendar Agenda**
   - Integrates directly with macOS `EventKit` (`EKEventStore`) to display an interactive 7-day calendar strip and color-coded upcoming events.

6. **Hardware Telemetry, Audio Switcher, Universal Earbuds HUD & Camera Mirror**
   - **Compact Wing Integration & Transient HUDs**: Displays live Dynamic Island HUD animations when plugging in MagSafe/AC power, connecting Bluetooth earbuds (Samsung Galaxy Buds, AirPods, Sony, Bose), or toggling system microphone mute.
   - **Hardware Telemetry Tab**: Real-time Apple Silicon CPU load, Unified Memory (RAM), Battery & MagSafe status, and SSD storage metrics via Mach kernel and IOKit APIs.
   - **Audio Device Quick Switcher & Mic Mute**: One-click CoreAudio output device switching (`MacBook Pro Speakers`, `Samsung Galaxy Buds`, `AirPods`, external displays) and system-wide microphone mute/unmute toggle.
   - **Quick Camera Mirror & Privacy HUD**: Horizontally mirrored `AVCaptureVideoPreviewLayer` viewport (`1.0x` / `1.3x` framing) with live Camera/Microphone hardware privacy indicators.

7. **Comprehensive Preferences & Live Notch Preview**
   - Split-view macOS Preferences window (`730 x 550 pt`) featuring an interactive Live Notch Preview banner and 6 configuration categories (`Appearance`, `Behavior`, `Modules`, `Media & Lyrics`, `Weather`, `System`).

---

## Project Structure

```text
Obelisk/
├── Package.swift
├── Info.plist
├── README.md
├── DOCUMENTATION.md
└── Sources/
    └── Obelisk/
        ├── App/
        │   ├── ObeliskApp.swift
        │   └── AppDelegate.swift
        ├── Core/
        │   ├── ScreenGeometry.swift
        │   ├── NotchWindow.swift
        │   └── WindowManager.swift
        ├── UI/
        │   ├── NotchShape.swift
        │   ├── RootView.swift
        │   ├── CompactNotchView.swift
        │   ├── ExpandedNotchView.swift
        │   └── SourceLogoView.swift
        ├── Pages/
        │   ├── Media/
        │   │   ├── MediaManager.swift
        │   │   ├── MediaRemoteBridge.swift
        │   │   ├── MediaArtworkService.swift
        │   │   ├── MediaPlayerView.swift
        │   │   ├── LyricsService.swift
        │   │   └── LyricsView.swift
        │   ├── Weather/
        │   │   ├── WeatherModels.swift
        │   │   ├── WeatherService.swift
        │   │   └── DetailedWeatherView.swift
        │   └── Calendar/
        │       ├── CalendarService.swift
        │       └── CalendarAgendaView.swift
        └── Settings/
            ├── ObeliskSettings.swift
            └── SettingsView.swift
```

---

## Building and Running

### Prerequisites
- macOS 13.0 (Ventura) or later (optimized for macOS 15+ / Tahoe on Apple Silicon `arm64`)
- Xcode Command Line Tools / Swift 5.9+

### Compile and Bundle `Obelisk.app`

```bash
cd Obelisk
swift build --scratch-path .build/out -c debug
cp .build/out/arm64-apple-macosx/debug/Obelisk .build/out/Products/Debug/Obelisk.app/Contents/MacOS/Obelisk
cp Info.plist .build/out/Products/Debug/Obelisk.app/Contents/Info.plist
codesign --force --deep --sign - .build/out/Products/Debug/Obelisk.app
```

### Launch Application

```bash
open .build/out/Products/Debug/Obelisk.app
```

For deep architectural and API documentation, see [DOCUMENTATION.md](DOCUMENTATION.md).
