# Obelisk — Native Dynamic Island for macOS

Obelisk is a native macOS utility built with Swift and SwiftUI for Apple Silicon MacBook models equipped with a physical display notch (including MacBook Pro M-series and MacBook Air M-series), as well as non-notch displays. It transforms the top camera bezel housing into an interactive, GPU-accelerated Dynamic Island featuring real-time media playback telemetry, millisecond-synchronized lyrics, live meteorological forecasts, native Apple Calendar integration, tri-engine notifications with Touch ID biometric protection, active browser download tracking, and bezel-matching transient system HUDs.

---

## Key Capabilities

1. **Hardware-Matched Notch Morphing and Dynamic Standby Wings**
   - Automatically queries `NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea` to match the exact physical notch dimensions (`185 x 32 pt` on MacBook Pro).
   - Standby notch wings feature mathematical centering between the physical display safe area cutout and the outer notch body curve, maintaining symmetric visual balance and equal margins regardless of configured width offset.
   - Real-time standby width customization (`40...380 pt`) in Settings with an isolated live preview canvas and instant discard restoration.
   - Single unified `NotchShape` container rendered inside a fixed transparent canvas so expansion and collapse animations run at 120Hz on the GPU without WindowServer frame-resize stutter.
   - Continuous mathematical pointer tracking (`NSEvent.mouseLocation`) prevents cursor tracking jitter across Desktop, windowed apps, and fullscreen Spaces.

2. **Real-Time Notification Island and Biometric Privacy**
   - Tri-Engine real-time notification monitor:
     - **Engine A (`usernoted` Unified Log Streamer):** Detects incoming local and push notifications in real time with zero latency, even when notifications are suppressed in the foreground.
     - **Engine B (`AXUIElement` Banner Inspector):** Reads rich sender and message body text from native Notification Center banners.
     - **Engine C (`AXUIElement` Catalyst Direct Inspector):** Directly captures WhatsApp messages when macOS banners are suppressed.
   - **Touch ID Biometric Protection:** Private notification cards are protected with hardware biometrics (`LocalAuthentication`). Notification content remains masked until authenticated, with direct single-click dismiss and seamless application activation.
   - **Notification History Drawer:** Stores recent notifications with timestamps, application badges, and one-click app launch.

3. **Active Download Tracking and Standby Progress**
   - Continuously monitors user Downloads directory across Safari, Chrome, Brave, Arc, and Firefox.
   - Displays real-time download progress percentages and file sizes directly on the standby notch wings.
   - Triggers elegant Dynamic Island completion banners upon download completion.

4. **Pure Floating Minimalist Dashboard**
   - Ultra-clean header layout featuring floating tab icons with an active glowing accent dot that dynamically reflects the artwork of the playing track.
   - Floating battery telemetry pill badge displaying real-time percentage and estimated charging time until full (or time remaining on battery).
   - Quick actions for horizontal mirror camera preview and preferences gear without unnecessary visual clutter.

5. **Universal Real-Time Media and Synchronized Lyrics**
   - Powered by a persistent Apple-signed MediaRemote XPC bridge (`MediaRemoteBridge.swift`) streaming calculated playback positions, durations, and native artwork buffers for **Spotify**, **Apple Music**, **YouTube**, **Vidio**, and **beIN Sports** across Safari, Chrome, Arc, Brave, and Edge.
   - **Millisecond-Accurate Synced Lyrics:** Queries the LRCLIB API with candidate pool proximity scoring and a 30Hz sub-second interpolation engine for smooth real-time lyric scrolling.
   - **Dynamic Standby Progress Bar:** Standby notch displays track time and a thin progress bar color-matched dynamically to the album artwork palette.
   - **Unified Audio Route Picker:** Instantly switch between MacBook speakers, AirPods, and connected Bluetooth audio devices directly from the Media tab.

6. **Proactive File Tray and Drop Zone (Auto-Open)**
   - Dragging any file or folder from Finder or Desktop towards the top notch bezel automatically expands directly into the **File Tray** shelf with zero dwell latency.
   - Stage files temporarily in the notch, drag them out into other applications (Slack, VS Code, WhatsApp), or share directly via native macOS AirDrop.
   - Thread-safe URL collection engine ensuring seamless multi-file drop processing without concurrency data races.

7. **Bezel-Matching Transient HUDs**
   - Replaces disruptive default macOS center-screen HUDs with sleek Dynamic Island morphing animations aligned with the physical notch:
     - **Volume HUD:** Minimalist slider with speaker icon.
     - **Brightness HUD:** Smooth slider with sun icon.
     - **Charging and Battery HUD:** AC/MagSafe connect and disconnect alerts with estimated charge duration.
     - **Caps Lock HUD:** Real-time state indicator for Caps Lock transitions.
     - **Focus and Do Not Disturb:** Fluid status indicator for Work, Sleep, and DND modes.

8. **Live Weather and Apple Calendar Agenda**
   - **Weather:** Real-time meteorological telemetry via Open-Meteo and CoreLocation (temperature, feels-like, 5-hour forecast, wind speed, UV index, humidity).
   - **Calendar:** Direct integration with macOS `EventKit` (`EKEventStore`) showing an interactive agenda strip with color-coded upcoming events and national holiday indicators.

9. **Strict Concurrency and Zero-Residue Architecture**
   - Fully compliant with Swift 6 Strict Concurrency (`-strict-concurrency=complete`) with zero data races.
   - Complete application lifecycle management: unhooks all CoreAudio property listeners, invalidates RunLoop timers, and terminates child processes cleanly on exit.
   - Integrated with Apple's modern `SMAppService.mainApp` API. Moving the app to Trash automatically and immediately unregisters the startup service with zero orphan entries.

---

## Installation

### 1. Download .dmg
Download the latest **`Obelisk.dmg`** installer directly from GitHub Releases:

**[Download Obelisk.dmg (Latest Release)](https://github.com/AlexanderSatryo/Obelisk/releases/latest/download/Obelisk.dmg)**

### 2. Install to Applications
1. Double-click the downloaded **`Obelisk.dmg`** to open the installer window.
2. Drag the **`Obelisk`** icon into the **`Applications`** folder shortcut.
3. Eject the disk image.

### 3. First-Time Launch (macOS Gatekeeper)
Because Obelisk is an independent open-source utility built for Apple Silicon:
1. Open your **Applications** folder in Finder.
2. **Right-click** on **`Obelisk`** -> select **Open** -> click **Open Anyway**.
   *(You only need to do this once. Alternatively, run: `xattr -cr /Applications/Obelisk.app` in Terminal).*
3. Click **Allow** when prompted for Calendar, Location, and Notification permissions so Obelisk can display your agenda, local weather, and incoming alerts.

---

## Updating Obelisk

Updating Obelisk is seamless and preserves all your configured preferences:
1. Download the new **`Obelisk.dmg`**.
2. Drag **`Obelisk.app`** into **`Applications`** and choose **Replace**.
3. Re-launch Obelisk. All settings, notch offsets, and tab configurations in `UserDefaults` remain intact.

---

## Uninstalling (Zero Residue)

Because Obelisk uses Apple's native `SMAppService` and standard macOS sandboxed preferences without root daemons or system extensions:
1. Quit Obelisk (via Settings or Menu Bar).
2. Drag **`Obelisk.app`** from `/Applications` to the **Trash**.
3. Empty Trash.
   - macOS automatically purges the startup registration immediately.
   - Your MacBook notch display instantly reverts to factory default.

---

## Project Structure

```text
Obelisk/
├── Package.swift
├── Info.plist
├── README.md
├── Documentation.md
├── Obelisk.dmg
└── Sources/
    └── Obelisk/
        ├── App/
        │   ├── Main.swift
        │   └── AppDelegate.swift
        ├── Core/
        │   ├── NotchWindow.swift
        │   ├── ScreenGeometry.swift
        │   └── WindowManager.swift
        ├── UI/
        │   ├── NotchShape.swift
        │   ├── CompactNotchView.swift
        │   ├── ExpandedNotchView.swift
        │   ├── NotchPageView.swift
        │   ├── NotchTransientHUDBar.swift
        │   ├── IndeterminateProgressBar.swift
        │   └── RootView.swift
        ├── Pages/
        │   ├── Media/
        │   │   ├── MediaManager.swift
        │   │   ├── MediaPlayerView.swift
        │   │   ├── MediaRemoteBridge.swift
        │   │   ├── MediaArtworkService.swift
        │   │   ├── LyricsService.swift
        │   │   ├── LyricsModel.swift
        │   │   ├── LyricsView.swift
        │   │   ├── SourceLogoView.swift
        │   │   └── TrackModel.swift
        │   ├── Notification/
        │   │   ├── ObeliskNotification.swift
        │   │   ├── NotificationService.swift
        │   │   ├── RealNotificationMonitor.swift
        │   │   ├── NotificationNotchView.swift
        │   │   ├── NotificationHistoryView.swift
        │   │   └── BiometricPrivacyService.swift
        │   ├── Weather/
        │   │   ├── WeatherService.swift
        │   │   ├── WeatherModel.swift
        │   │   └── DetailedWeatherView.swift
        │   ├── Calendar/
        │   │   ├── CalendarService.swift
        │   │   ├── CalendarModel.swift
        │   │   └── CalendarAgendaView.swift
        │   ├── File/
        │   │   ├── FileTrayService.swift
        │   │   └── FileTrayView.swift
        │   ├── Download/
        │   │   └── DownloadMonitorService.swift
        │   └── System/
        │       ├── HardwareTelemetryService.swift
        │       ├── AudioPeripheralsService.swift
        │       ├── CameraMirrorService.swift
        │       ├── CameraMirrorView.swift
        │       ├── CapsLockMonitorService.swift
        │       └── SystemVolumeAndBrightnessMonitor.swift
        └── Settings/
            ├── ObeliskSettings.swift
            └── SettingsView.swift
```

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
