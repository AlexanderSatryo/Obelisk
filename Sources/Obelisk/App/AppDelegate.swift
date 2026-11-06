import AppKit

/// Application lifecycle delegate for Obelisk.
/// Configures the app as a background accessory (no Dock icon), warms up core services,
/// manages the menu bar `NSStatusItem`, and initializes the floating `NotchWindow`.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        _ = ObeliskSettings.shared
        _ = MediaManager.shared
        _ = WeatherService.shared
        _ = CalendarService.shared
        _ = HardwareTelemetryService.shared
        _ = AudioPeripheralsService.shared
        _ = CameraMirrorService.shared
        SystemVolumeAndBrightnessMonitor.shared.startMonitoring()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuBarVisibilityChange),
            name: .obeliskMenuBarVisibilityChanged,
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(openSettings),
            name: Notification.Name("com.obelisk.openSettings"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(openSettings),
            name: Notification.Name("com.obelisk.openSettings"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(toggleNotch),
            name: Notification.Name("com.obelisk.toggleNotch"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(expandNotch),
            name: Notification.Name("com.obelisk.expandNotch"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(switchMedia),
            name: Notification.Name("com.obelisk.switchMedia"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(switchWeather),
            name: Notification.Name("com.obelisk.switchWeather"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(switchCalendar),
            name: Notification.Name("com.obelisk.switchCalendar"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(switchFile),
            name: Notification.Name("com.obelisk.switchFile"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(toggleLyrics),
            name: Notification.Name("com.obelisk.toggleLyrics"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(collapseNotch),
            name: Notification.Name("com.obelisk.collapseNotch"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testBatteryHUD),
            name: Notification.Name("com.obelisk.testBatteryHUD"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testVolumeHUD),
            name: Notification.Name("com.obelisk.testVolumeHUD"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testBrightnessHUD),
            name: Notification.Name("com.obelisk.testBrightnessHUD"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testBatteryUnpluggedHUD),
            name: Notification.Name("com.obelisk.testBatteryUnpluggedHUD"),
            object: nil
        )

        updateStatusItemVisibility()
        WindowManager.shared.setupWindow()
    }

    @objc private func handleMenuBarVisibilityChange() {
        updateStatusItemVisibility()
    }

    private func updateStatusItemVisibility() {
        if ObeliskSettings.shared.showMenuBarIcon {
            if statusItem == nil {
                setupStatusItem()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "Obelisk")
        }

        let menu = NSMenu()
        let headerItem = NSMenuItem(title: "Obelisk", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(
            title: "Toggle Notch Expand",
            action: #selector(toggleNotch),
            keyEquivalent: "o"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Obelisk",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowManager.shared.showSettings()
        return true
    }

    @objc private func toggleNotch() {
        Task { @MainActor in
            WindowManager.shared.toggleExpand()
        }
    }

    @objc private func expandNotch() {
        Task { @MainActor in
            WindowManager.shared.expand()
        }
    }

    @objc private func switchMedia() {
        Task { @MainActor in
            WindowManager.shared.switchToTab(.media)
        }
    }

    @objc private func switchWeather() {
        Task { @MainActor in
            WindowManager.shared.switchToTab(.weather)
        }
    }

    @objc private func switchCalendar() {
        Task { @MainActor in
            WindowManager.shared.switchToTab(.calendar)
        }
    }

    @objc private func switchFile() {
        Task { @MainActor in
            WindowManager.shared.switchToTab(.file)
        }
    }

    @objc private func toggleLyrics() {
        Task { @MainActor in
            ObeliskSettings.shared.showLyricsInNotch.toggle()
        }
    }

    @objc private func collapseNotch() {
        Task { @MainActor in
            WindowManager.shared.collapse()
        }
    }

    @objc private func testBatteryHUD() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .battery(
                    percentage: 85,
                    isCharging: true,
                    statusText: "85% • 24m until full"
                ),
                duration: 4.0
            )
        }
    }

    @objc private func testVolumeHUD() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .volume(
                    level: 0.72,
                    isMuted: false
                ),
                duration: 4.0
            )
        }
    }

    @objc private func testBrightnessHUD() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .brightness(
                    level: 0.85
                ),
                duration: 4.0
            )
        }
    }

    @objc private func testBatteryUnpluggedHUD() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .battery(
                    percentage: 85,
                    isCharging: false,
                    statusText: "Disconnected"
                ),
                duration: 4.0
            )
        }
    }

    @objc private func openSettings() {
        SettingsWindowManager.shared.showSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
