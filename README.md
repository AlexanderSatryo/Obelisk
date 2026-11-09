# Obelisk — Native Dynamic Island for macOS

Obelisk is a native macOS application for Apple Silicon MacBooks (as well as external monitors) that turns the notch area into an interactive Dynamic Island. It provides media playback controls, synchronized lyrics, incoming notification alerts with Touch ID privacy, a file drop shelf, active download tracking, weather forecasts, calendar events, and system status indicators.

---

## Features

1. **Notch Display and Customization**
   - Automatically detects and aligns with the MacBook notch dimensions.
   - Expand and collapse smoothly by hovering your mouse or clicking.
   - Customize the standby notch width in Settings (from 40 to 380 pt) with a live preview and discard button.
   - Content on the left and right sides stays centered regardless of the width you choose.

2. **Incoming Notifications and Privacy**
   - Displays incoming notifications (such as WhatsApp, Messages, and other apps) directly at the notch.
   - Private notification content can be unlocked using Touch ID.
   - Includes a notification history tab to view recent alerts and open their source applications with one click.

3. **Media Player and Synchronized Lyrics**
   - Supports Spotify, Apple Music, YouTube, and other browsers and media players.
   - Displays the current song title, artist, album art, and progress bar.
   - Real-time synchronized lyrics that scroll automatically with the music.
   - Audio output selector to quickly switch between MacBook speakers, AirPods, and Bluetooth devices.

4. **File Tray**
   - Drag and drop files or folders to the notch to temporarily store them.
   - Drag stored files out to other applications (Finder, WhatsApp, Slack, etc.) or share directly via AirDrop.

5. **Download Progress Tracking**
   - Tracks active browser downloads from Safari, Chrome, Brave, Arc, and Firefox.
   - Displays real-time download percentage, file name, and file size in the notch.
   - Shows a notification banner when a download finishes.

6. **Weather and Calendar**
   - Weather: Shows current temperature, weather conditions, wind speed, humidity, and hourly forecast.
   - Calendar: Shows upcoming events, dates, and schedules from Apple Calendar.

7. **System Indicators**
   - Replaces default screen pop-ups with compact indicators at the notch:
     - Volume level and mute state.
     - Screen brightness level.
     - Battery percentage, charger connection status, and remaining charge time.
     - Caps Lock status.
   - Quick camera mirror to preview your front camera directly from the notch.

---

## Installation

### 1. Download .dmg
Download the latest **`Obelisk.dmg`** installer directly from GitHub Releases:

**[Download Obelisk.dmg (Latest Release)](https://github.com/AlexanderSatryo/Obelisk/releases/latest/download/Obelisk.dmg)**

### 2. Install to Applications
1. Double-click the downloaded **`Obelisk.dmg`** file.
2. Drag the **`Obelisk`** icon into the **`Applications`** folder.
3. Eject the disk image.

### 3. First-Time Launch (macOS Gatekeeper)
Because Obelisk is an independent open-source application:
1. Open your **Applications** folder in Finder.
2. Right-click on **`Obelisk`** -> select **Open** -> click **Open Anyway**.
   *(You only need to do this once. Alternatively, run: `xattr -cr /Applications/Obelisk.app` in Terminal).*
3. Grant permissions for Calendar, Location, and Notifications when prompted so Obelisk can display your schedule, weather, and alerts.

---

## Updating Obelisk

To update Obelisk:
1. Download the latest **`Obelisk.dmg`**.
2. Drag **`Obelisk.app`** into **`Applications`** and select **Replace**.
3. Open Obelisk again. All your settings and preferences remain saved.

---

## Uninstalling

To uninstall Obelisk:
1. Quit Obelisk.
2. Move **`Obelisk.app`** from `/Applications` to the **Trash**.
3. Empty Trash.
   - Startup registrations are removed automatically with no leftover background processes.

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
