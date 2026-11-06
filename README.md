# Obelisk — Native Dynamic Island for macOS

Obelisk is a native macOS utility built with Swift and SwiftUI for Apple Silicon MacBook models equipped with a physical display notch (including MacBook Pro M-series and MacBook Air M-series), as well as non-notch displays. It transforms the top camera bezel housing into an interactive, GPU-accelerated Dynamic Island featuring real-time media playback telemetry, millisecond-synchronized lyrics, live meteorological forecasts, native Apple Calendar integration, and bezel-matching transient system HUDs.

---

## Key Capabilities

1. **Hardware-Matched Notch Morphing**
   - Automatically queries `NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea` to match the exact physical notch dimensions (`185 x 32 pt` on MacBook Pro).
   - Single unified `NotchShape` container rendered inside a fixed transparent canvas so expansion and collapse animations run at 120Hz on the GPU without WindowServer frame-resize stutter.
   - Continuous mathematical pointer tracking (`NSEvent.mouseLocation`) prevents cursor tracking jitter across Desktop, windowed apps, and fullscreen Spaces.

2. **Pure Floating Minimalist Dashboard**
   - Ultra-clean header layout featuring floating tab icons with an active glowing accent dot that dynamically reflects the artwork of the playing track.
   - Floating battery telemetry pill badge displaying real-time percentage and estimated charging time until full (or time remaining on battery).
   - Quick actions for horizontal mirror camera preview and preferences gear without unnecessary arrows or visual clutter.

3. **Universal Real-Time Media & Synchronized Lyrics**
   - Powered by a persistent Apple-signed MediaRemote XPC bridge (`MediaRemoteBridge.swift`) streaming calculated playback positions, durations, and native artwork buffers for **Spotify**, **Apple Music**, **YouTube**, **Vidio**, and **beIN Sports** across Safari, Chrome, Arc, Brave, and Edge.
   - **Millisecond-Accurate Synced Lyrics:** Queries the LRCLIB API with candidate pool proximity scoring (matching track duration within 0.35s to filter radio edits and live versions) and a 30Hz sub-second interpolation engine for smooth real-time lyric scrolling.
   - **Dynamic Standby Progress Bar:** Standby notch displays track time and a thin progress bar color-matched dynamically to the album artwork palette.

4. **Proactive File Tray & Drop Zone (Auto-Open)**
   - Dragging any file or folder from Finder or Desktop towards the top notch bezel automatically expands directly into the **File Tray** shelf with zero dwell latency.
   - Stage files temporarily in the notch, drag them out into other applications (Slack, VS Code, WhatsApp), or share directly via native macOS AirDrop.
   - File drag auto-expansion preserves user tab memory without overriding manual tab preferences.

5. **Bezel-Matching Transient HUDs**
   - Replaces disruptive default macOS center-screen HUDs with sleek Dynamic Island morphing animations aligned with the physical notch:
     - **Volume HUD:** Minimalist slider with speaker icon.
     - **Brightness HUD:** Smooth slider with sun icon.
     - **Charging & Battery HUD:** AC/MagSafe connect and disconnect alerts with estimated charge duration.
     - **Focus & Do Not Disturb:** Fluid status indicator for Work, Sleep, and DND modes.

6. **Live Weather & Apple Calendar Agenda**
   - **Weather:** Real-time meteorological telemetry via Open-Meteo and CoreLocation (temperature, feels-like, 5-hour forecast, wind speed, UV index, humidity).
   - **Calendar:** Direct integration with macOS `EventKit` (`EKEventStore`) showing a 7-day interactive agenda strip with color-coded upcoming events.

7. **Modern Zero-Residue Launch at Login**
   - Integrated with Apple's modern `SMAppService.mainApp` API. Moving the app to Trash automatically and immediately unregisters the startup service with zero orphan entries.

---

## Installation Guide

### Option 1: Install via `.dmg` (Recommended)

1. **Download the Installer:**
   - Get the latest **`Obelisk.dmg`** from the repository releases or project folder.
2. **Install to Applications:**
   - Double-click **`Obelisk.dmg`** to mount the installer window.
   - Drag **`Obelisk.app`** into the **`Applications`** folder shortcut.
   - Eject the disk image once copying is complete.
3. **First-Time Launch (macOS Gatekeeper):**
   - Open your **Applications** folder in Finder.
   - **Right-click** on **`Obelisk.app`** $\rightarrow$ select **Open** $\rightarrow$ click **Open Anyway**.
     *(You only need to do this once. Alternatively, run: `xattr -cr /Applications/Obelisk.app` in Terminal).*
4. **Grant System Permissions:**
   - Click **Allow** when prompted for Calendar and Location permissions so Obelisk can display your agenda and local weather.

---

### Option 2: Build From Source (Developers)

#### Prerequisites
- macOS 13.0 (Ventura) or later (Apple Silicon M-series recommended)
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+

#### Build Release Binary & Bundle

```bash
# 1. Clone repository
git clone https://github.com/USERNAME/Obelisk.git
cd Obelisk

# 2. Compile optimized production release build
swift build -c release

# 3. Create standalone .app bundle
STAGING="/tmp/Obelisk-Staging"
mkdir -p "$STAGING/Obelisk.app/Contents/MacOS"
mkdir -p "$STAGING/Obelisk.app/Contents/Resources"

cp ".build/out/Products/Release/Obelisk" "$STAGING/Obelisk.app/Contents/MacOS/Obelisk"
cp "Info.plist" "$STAGING/Obelisk.app/Contents/Info.plist"
echo -n "APPL????" > "$STAGING/Obelisk.app/Contents/PkgInfo"

# 4. Sign the bundle ad-hoc
codesign --force --deep --sign - "$STAGING/Obelisk.app"

# 5. Move into Applications
cp -R "$STAGING/Obelisk.app" /Applications/
```

#### Generate `.dmg` Installer Package

```bash
mkdir -p /tmp/DMG-Staging
cp -R /tmp/Obelisk-Staging/Obelisk.app /tmp/DMG-Staging/
ln -s /Applications /tmp/DMG-Staging/Applications
hdiutil create -volname "Obelisk" -srcfolder /tmp/DMG-Staging -ov -format UDZO Obelisk.dmg
```

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
        │       ├── SystemHubView.swift
        │       └── SystemVolumeAndBrightnessMonitor.swift
        ├── Gesture/
        │   └── TrackpadSwipeReceiver.swift
        └── Settings/
            ├── ObeliskSettings.swift
            └── SettingsView.swift
```

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
