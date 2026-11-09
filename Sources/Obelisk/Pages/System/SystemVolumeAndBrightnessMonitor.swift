import Foundation
import AppKit
import CoreAudio
import AudioToolbox
import CoreGraphics

/// Monitors macOS system output volume, mute state, and built-in display brightness.
/// Dispatches transient HUD bars on the notch (both in standby and extended mode)
/// whenever the user adjusts volume or brightness (+ / -).
@MainActor
public final class SystemVolumeAndBrightnessMonitor {
    public static let shared = SystemVolumeAndBrightnessMonitor()

    private var lastVolume: Float32 = -1
    private var lastMute: Bool = false
    private var lastBrightness: Float = -1
    private var lastDeviceSwitchTime: Date = .distantPast
    private var isInitialized: Bool = false
    private var pollTimer: Timer?

    private var activeDeviceID: AudioDeviceID? = nil
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock? = nil
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock? = nil

    private typealias DisplayServicesGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private var getBrightnessFn: DisplayServicesGetBrightnessFunc?

    private init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
                self.getBrightnessFn = unsafeBitCast(sym, to: DisplayServicesGetBrightnessFunc.self)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopMonitoring()
            }
        }
    }

    /// Begins monitoring volume and display brightness changes.
    public func startMonitoring() {
        guard !isInitialized else { return }
        let (vol, mute) = readCurrentAudioState()
        self.lastVolume = vol
        self.lastMute = mute
        self.lastBrightness = readCurrentBrightness()
        self.isInitialized = true

        setupAudioListener()
        startPolling()
    }

    /// Stops monitoring and unhooks all CoreAudio property listeners and runloop timers.
    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil

        removeDeviceListener()
        removeDefaultDeviceListener()

        isInitialized = false
    }

    private func removeDeviceListener() {
        guard let devID = activeDeviceID, let block = deviceListenerBlock else { return }
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(devID, &volAddr, DispatchQueue.main, block)

        var scalarAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(devID, &scalarAddr, DispatchQueue.main, block)

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(devID, &muteAddr, DispatchQueue.main, block)

        self.activeDeviceID = nil
        self.deviceListenerBlock = nil
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        var defaultDevAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDevAddr, DispatchQueue.main, block)
        self.defaultDeviceListenerBlock = nil
    }

    private func setupAudioListener() {
        let devID = defaultOutputDeviceID()
        guard devID != 0 else { return }

        // Remove listener from previous device if switched
        if activeDeviceID != devID {
            removeDeviceListener()
        }

        if deviceListenerBlock == nil {
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in
                    self?.checkHardwareChanges()
                }
            }
            self.deviceListenerBlock = listener

            var volAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectAddPropertyListenerBlock(devID, &volAddr, DispatchQueue.main, listener)

            var scalarAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectAddPropertyListenerBlock(devID, &scalarAddr, DispatchQueue.main, listener)

            var muteAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectAddPropertyListenerBlock(devID, &muteAddr, DispatchQueue.main, listener)

            self.activeDeviceID = devID
        }

        // Listen for default output device changes once (e.g. plugging in headphones or connecting AirPods)
        if defaultDeviceListenerBlock == nil {
            var defaultDevAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let defListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.setupAudioListener()
                    let (newVol, newMute) = self.readCurrentAudioState()
                    self.lastVolume = newVol
                    self.lastMute = newMute
                    self.lastDeviceSwitchTime = Date()
                }
            }
            _ = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDevAddr, DispatchQueue.main, defListener)
            self.defaultDeviceListenerBlock = defListener
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        // Fast 35ms polling interval (approx. 30 FPS) for buttery smooth brightness and audio tracking
        let timer = Timer(timeInterval: 0.035, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkHardwareChanges()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }

    private func checkHardwareChanges() {
        guard isInitialized else { return }

        // 1. Check Volume & Mute
        let (vol, mute) = readCurrentAudioState()
        let volDiff = abs(vol - lastVolume)
        let volChanged = volDiff > 0.005
        let muteChanged = (mute != lastMute)

        if volChanged || muteChanged {
            self.lastVolume = vol
            self.lastMute = mute

            let timeSinceDeviceSwitch = Date().timeIntervalSince(self.lastDeviceSwitchTime)
            let isRecentDeviceSwitch = timeSinceDeviceSwitch >= 0 && timeSinceDeviceSwitch < 3.5

            let timeSinceBTAnnounce = Date().timeIntervalSince(AudioPeripheralsService.shared.lastAnnouncedTime)
            let isRecentBTAnnounce = timeSinceBTAnnounce >= 0 && timeSinceBTAnnounce < 3.5

            let isDeviceHUDActive: Bool = {
                if let hud = HardwareTelemetryService.shared.activeTransientHUD {
                    switch hud {
                    case .deviceConnected, .deviceDisconnected:
                        return true
                    default:
                        return false
                    }
                }
                return false
            }()

            // Suppress volume HUD during device connection transitions so it does not overwrite the earbuds notification
            if !isRecentDeviceSwitch && !isRecentBTAnnounce && !isDeviceHUDActive {
                HardwareTelemetryService.shared.triggerTransientHUD(
                    .volume(level: Double(vol), isMuted: mute),
                    duration: 1.8
                )
            }
        }

        // 2. Check Display Brightness
        let brightness = readCurrentBrightness()
        if brightness >= 0 {
            let brightDiff = abs(brightness - lastBrightness)
            if brightDiff > 0.005 {
                self.lastBrightness = brightness

                // If charger was recently connected or disconnected, or any battery HUD is active, ignore brightness auto-ramp
                let timeSincePlug = Date().timeIntervalSince(HardwareTelemetryService.shared.lastChargerConnectionTime)
                let timeSinceUnplug = Date().timeIntervalSince(HardwareTelemetryService.shared.lastChargerDisconnectionTime)
                let isRecentPowerTransition = (timeSincePlug >= 0 && timeSincePlug < 3.5) || (timeSinceUnplug >= 0 && timeSinceUnplug < 3.5)
                let isBatteryHUDActive: Bool = {
                    if let hud = HardwareTelemetryService.shared.activeTransientHUD,
                       case .battery = hud {
                        return true
                    }
                    return false
                }()

                if !isRecentPowerTransition && !isBatteryHUDActive {
                    HardwareTelemetryService.shared.triggerTransientHUD(
                        .brightness(level: Double(brightness)),
                        duration: 1.8
                    )
                }
            }
        }
    }

    // MARK: - Audio Volume & Mute Helpers

    private func defaultOutputDeviceID() -> AudioDeviceID {
        var devID = AudioDeviceID(0)
        var devSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var devAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &devAddr,
            0,
            nil,
            &devSize,
            &devID
        )
        return (status == noErr) ? devID : 0
    }

    private func readCurrentAudioState() -> (volume: Float32, isMuted: Bool) {
        let devID = defaultOutputDeviceID()
        guard devID != 0 else { return (0.5, false) }

        var vol: Float32 = 0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyData(devID, &volAddr, 0, nil, &volSize, &vol)
        if status != noErr {
            volAddr.mSelector = kAudioDevicePropertyVolumeScalar
            status = AudioObjectGetPropertyData(devID, &volAddr, 0, nil, &volSize, &vol)
        }

        var mute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectGetPropertyData(devID, &muteAddr, 0, nil, &muteSize, &mute)

        return (max(0, min(1.0, vol)), mute != 0)
    }

    // MARK: - Display Brightness Helper

    private func readCurrentBrightness() -> Float {
        guard let fn = getBrightnessFn else { return -1 }
        var brightness: Float = 0
        let status = fn(CGMainDisplayID(), &brightness)
        return (status == 0) ? max(0, min(1.0, brightness)) : -1
    }
}

