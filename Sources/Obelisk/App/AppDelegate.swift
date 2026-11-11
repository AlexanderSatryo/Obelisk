import AppKit

/// Application lifecycle delegate for Obelisk.
/// Configures the app as a background accessory (no Dock icon), warms up core services,
/// manages the menu bar `NSStatusItem`, and initializes the floating `NotchWindow`.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureApplicationIcon()

        _ = ObeliskSettings.shared
        _ = MediaManager.shared
        _ = WeatherService.shared
        _ = CalendarService.shared
        _ = HardwareTelemetryService.shared
        _ = AudioPeripheralsService.shared
        _ = CameraMirrorService.shared
        _ = BiometricPrivacyService.shared
        _ = NotificationService.shared
        RealNotificationMonitor.shared.startMonitoring()
        SystemVolumeAndBrightnessMonitor.shared.startMonitoring()
        CapsLockMonitorService.shared.startMonitoring()

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
            selector: #selector(switchNotification),
            name: Notification.Name("com.obelisk.switchNotification"),
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
            selector: #selector(testCapsLockOn),
            name: Notification.Name("com.obelisk.testCapsLockOn"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testCapsLockOff),
            name: Notification.Name("com.obelisk.testCapsLockOff"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testEarbudsConnect),
            name: Notification.Name("com.obelisk.testEarbudsConnect"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testEarbudsDisconnect),
            name: Notification.Name("com.obelisk.testEarbudsDisconnect"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testDownloadProgress),
            name: Notification.Name("com.obelisk.testDownloadProgress"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testDownloadIndeterminate),
            name: Notification.Name("com.obelisk.testDownloadIndeterminate"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testDownloadShort),
            name: Notification.Name("com.obelisk.testDownloadShort"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testDownloadLong),
            name: Notification.Name("com.obelisk.testDownloadLong"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testDownloadComplete),
            name: Notification.Name("com.obelisk.testDownloadComplete"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testDownloadFailed),
            name: Notification.Name("com.obelisk.testDownloadFailed"),
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
            selector: #selector(testBatteryFullyChargedHUD),
            name: Notification.Name("com.obelisk.testBatteryFullyChargedHUD"),
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

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(dismissNotificationHUD),
            name: Notification.Name("com.obelisk.dismissNotification"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testUnlockNotification),
            name: Notification.Name("com.obelisk.testUnlockNotification"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(clearRecentNotifications),
            name: Notification.Name("com.obelisk.clearNotifications"),
            object: nil
        )

        updateStatusItemVisibility()
        WindowManager.shared.setupWindow()
    }

    private func configureApplicationIcon() {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }
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

    @objc private func switchNotification() {
        Task { @MainActor in
            let wm = WindowManager.shared
            if !wm.isExpanded {
                wm.expand(openingTab: .notification)
            } else {
                wm.switchToTab(.notification)
            }
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

    @objc private func testBatteryFullyChargedHUD() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerBatteryFullyChargedHUD()
        }
    }

    @objc private func testVolumeHUD() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .volume(
                    level: 0.72,
                    isMuted: false,
                    deviceName: "Satryo's Buds",
                    isHeadphones: true
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

    @objc private func testCapsLockOn() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .capsLock(isOn: true),
                duration: 2.5
            )
        }
    }

    @objc private func testCapsLockOff() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .capsLock(isOn: false),
                duration: 2.5
            )
        }
    }

    @objc private func testEarbudsConnect() {
        Task { @MainActor in
            AudioPeripheralsService.shared.announceConnectedDevice(
                name: "AirPods Pro",
                icon: "airpodspro"
            )
        }
    }

    @objc private func testEarbudsDisconnect() {
        Task { @MainActor in
            AudioPeripheralsService.shared.announceDisconnectedDevice(
                name: "AirPods Pro",
                icon: "airpodspro"
            )
        }
    }

    @objc private func testDownloadProgress() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .download(
                    fileName: "Xcode_16.1.xip",
                    statusText: "68%",
                    isSuccess: true,
                    progress: 0.68
                ),
                duration: 3.5
            )
        }
    }

    @objc private func testDownloadIndeterminate() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .download(
                    fileName: "Unconfirmed 5212",
                    statusText: "176 MB",
                    isSuccess: true,
                    progress: nil
                ),
                duration: 3.5
            )
        }
    }

    @objc private func testDownloadShort() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .download(
                    fileName: "app.zip",
                    statusText: "12 MB",
                    isSuccess: true,
                    progress: nil
                ),
                duration: 3.5
            )
        }
    }

    @objc private func testDownloadLong() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .download(
                    fileName: "macOS_Tahoe_Developer_Preview_Build_24A102.pkg",
                    statusText: "4.8 GB",
                    isSuccess: true,
                    progress: nil
                ),
                duration: 3.5
            )
        }
    }

    @objc private func testDownloadComplete() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .download(
                    fileName: "Xcode_16.1.xip",
                    statusText: "Download Complete",
                    isSuccess: true,
                    progress: nil
                ),
                duration: 3.5
            )
        }
    }

    @objc private func testDownloadFailed() {
        Task { @MainActor in
            HardwareTelemetryService.shared.triggerTransientHUD(
                .download(
                    fileName: "macOS_Sequoia.iso",
                    statusText: "Download Failed",
                    isSuccess: false,
                    progress: nil
                ),
                duration: 3.5
            )
        }
    }

    @objc private func dismissNotificationHUD() {
        Task { @MainActor in
            NotificationService.shared.dismissNotification()
        }
    }

    @objc private func testUnlockNotification() {
        Task { @MainActor in
            BiometricPrivacyService.shared.isUnlocked = true
        }
    }

    @objc private func clearRecentNotifications() {
        Task { @MainActor in
            NotificationService.shared.clearAllRecentNotifications()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        RealNotificationMonitor.shared.stopMonitoring()
        SystemVolumeAndBrightnessMonitor.shared.stopMonitoring()
        CapsLockMonitorService.shared.stopMonitoring()
        DownloadMonitorService.shared.stopMonitoring()
        WindowManager.shared.stopUnifiedCursorMonitor()
    }

    @objc private func openSettings() {
        SettingsWindowManager.shared.showSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
