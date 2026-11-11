# Obelisk — Native Dynamic Island for macOS

Obelisk is a native macOS application for Apple Silicon MacBooks (as well as external monitors) that turns the notch area into an interactive Dynamic Island. It provides media playback controls, synchronized lyrics, incoming notification alerts with Touch ID privacy, a file drop shelf, active download tracking, weather forecasts, calendar events, and system status indicators.

---

## Features (v1.1.1)

1. **Notch Display and Customization**
   - Automatically detects and aligns with native MacBook notch dimensions (and simulates on external displays).
   - Expand and collapse smoothly via hover, click, or trackpad gestures.
   - Independent Appearance controls in Settings:
     - **Compact Notch**: Customize standby width (40 to 380 pt) with live preview and centered side content.
     - **Expanded Dashboard**: Configure layout dimensions and animation parameters.
   - Horizontal multi-page swipe navigation with natural gesture direction enabled by default.

2. **Incoming Notifications and Touch ID Privacy**
   - Displays real-time notification banners (WhatsApp, Messages, Slack, Telegram, etc.) directly in the notch.
   - Biometric privacy protection: Private message contents unlock with Touch ID, featuring an illuminated green fingerprint glyph and sonar ripple animation.
   - Built-in notification history tab to review recent alerts and open originating apps in one click.

3. **Media Player and Synchronized Lyrics**
   - Integrates with Spotify, Apple Music, YouTube, and media-playing browsers.
   - Displays track title, artist name, live album artwork, and interactive scrubber.
   - Real-time synchronized lyrics scrolling with playback timing.
   - Audio output selector for rapid switching between built-in speakers, AirPods, and Bluetooth devices.

4. **File Tray and Direct Drag Interaction**
   - Dragging any file or folder toward the notch automatically opens the File Tray page.
   - Temporarily stages dragged files for quick access.
   - Drag staged files directly into other applications (Finder, Mail, Slack, WhatsApp) or share via AirDrop.

5. **Download Progress Tracking**
   - Actively monitors file downloads from Safari, Chrome, Brave, Arc, and Firefox.
   - Displays a live progress bar with completion percentage and file name.
   - Automatically cleans up on download completion, cancellation, or pause.
   - Alerts with a completion notification banner once the file is ready.

6. **Weather and Calendar**
   - Weather: Real-time temperature, condition indicators, humidity, wind velocity, and hourly forecast.
   - Calendar: Displays upcoming schedule, event timings, and meeting details synced from Apple Calendar.

7. **Scheduled Alerts and Routine Alarms**
   - Dedicated dashboard tab positioned directly before Notifications with clean Apple-native design.
   - Configure routine reminders for work attendance, lunch breaks, medication, daily meetings, or custom routines.
   - Flexible recurrence options: **Daily**, **Weekdays (Mon - Fri)**, **Weekends (Sat - Sun)**, and **One-time**.
   - Tactile time controls with increment/decrement steppers and direct numeric keyboard entry.
   - Standby Notch Alert HUD featuring an animated swinging bell and time badge on the left wing, and reminder title + amber `[ OK ]` confirmation button on the right wing.
   - Configurable standby alert duration (1, 2, 3, 5, 10 minutes, or until dismissed) and "Require OK to Dismiss" toggle in Settings (`Modules` > `SCHEDULED ALERTS & ALARMS`).

8. **Native macOS Shortcut Integration**
   - Full support for standard macOS editing shortcuts (`⌘ + C`, `⌘ + V`, `⌘ + A`, `⌘ + X`, `⌘ + Z`, `⇧ + ⌘ + Z`) across all text fields and input forms in the application.
   - Operates seamlessly within the custom floating notch window environment without requiring traditional system menu bar edit items.

9. **System Indicators and Native HUD Replacement**
   - **Native macOS OSD Interception**: Suppresses standard floating pop-up overlays for volume and brightness, rendering them smoothly inside the notch instead.
   - **Smart Audio Output Recognition**: Distinguishes between headphones (earbuds, AirPods, headsets) and speakers (built-in speakers, Bluetooth speakers, external audio) with tailored icons and displays the active device name.
   - **Flicker-Free HUD Slider**: Smooth fluid slider transitions during repeated keystrokes with zero view blinking or notch jitter.
   - **System Telemetry**: Real-time notch badges for battery percentage, charging state, disconnect alerts, and Caps Lock status.
   - **Quick Camera Mirror**: Instant front camera preview toggle directly from the notch.

---

## Release History

### Version 1.1.1 (Latest)
- **Scheduled Alerts and Routine Alarms**: Dedicated dashboard tab with recurring routines (Daily, Weekdays, Weekends, One-time), tactile time controls, and standby notch alert HUD with animated swinging bell and OK button.
- **Native macOS Shortcut Integration**: Full support for standard macOS editing shortcuts (`⌘ + C`, `⌘ + V`, `⌘ + A`, `⌘ + X`, `⌘ + Z`, `⇧ + ⌘ + Z`) across all text fields and input forms in the application.
- **Notification Clipping Fix**: Fixed an issue where collapsing the notch while an incoming alert arrived could clip the notification text. Dynamic wing expansion now expands smoothly up to 280 pt with symmetric morphing.
- **Alert Page Auto-Collapse**: Fixed cursor focus tracking so the expanded notch reliably auto-collapses when the mouse exits the alert tab according to the configured exit grace period.

### Version 1.1
- **Native OSD Suppression**: Intercepts keyboard media keys to suppress default macOS volume and brightness pop-up overlays, displaying them directly in the notch.
- **Smart Audio Output Detection**: Distinguishes between headphones and speakers with dedicated icons, and displays connected Bluetooth device names.
- **Smooth Notch HUD Animation**: Glides the volume and brightness indicators smoothly without flickering or frame jitter.
- **Touch ID Fingerprint Animation**: Replaced the padlock icon with a responsive fingerprint glyph and emerald sonar ripple on successful authentication.
- **Separated Appearance Settings**: Configures Compact Notch and Expanded Dashboard options independently with real-time preview synchronization.
- **Direct File Drag Interaction**: Dragging files toward the notch automatically switches to the file shelf.
- **Updated Default Settings**: Inverted horizontal swipe navigation and Launch at Login are now enabled by default.

### Version 1.0
- **Dynamic Notch Display**: Native Apple Silicon notch integration with configurable standby width and smooth expansion.
- **Media Player and Synchronized Lyrics**: Playback controls with real-time scrolling lyrics for Spotify, Apple Music, YouTube, and web browsers.
- **Incoming Notifications and Biometric Privacy**: Displays application notifications with Touch ID lock for sensitive alerts.
- **File Tray**: Drag-and-drop temporary file shelf for quick staging and sharing.
- **Download Progress Tracking**: Active download monitoring for Safari, Chrome, Firefox, Arc, and Brave.
- **Weather and Calendar**: Current temperature, forecasts, and Apple Calendar schedule integration.
- **System Indicators**: Notch-based indicators for battery level, charging status, volume, brightness, and Caps Lock.

---

## Installation

### 1. Download .dmg
Download the latest **`Obelisk.dmg`** installer directly from GitHub Releases:

**[Download Obelisk.dmg (v1.1.1)](https://github.com/AlexanderSatryo/Obelisk/releases/latest/download/Obelisk.dmg)**

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
        │   ├── SwingingBellIconView.swift
        │   └── RootView.swift
        ├── Pages/
        │   ├── Alert/
        │   │   ├── ScheduledAlertModel.swift
        │   │   ├── ScheduledAlertService.swift
        │   │   └── ScheduledAlertsPageView.swift
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
