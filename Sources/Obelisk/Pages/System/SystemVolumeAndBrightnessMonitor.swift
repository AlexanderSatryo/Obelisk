import Foundation
import AppKit
import CoreAudio
import AudioToolbox
import CoreGraphics
import ApplicationServices

/// Monitors macOS system output volume, mute state, and built-in display brightness.
/// Intercepts hardware media keys via CGEventTap to suppress macOS native floating OSD pills
/// and dispatches sleek, contextual HUD bars on the notch (displaying connected device name like "Satryo's Buds").
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
    private typealias DisplayServicesSetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private var getBrightnessFn: DisplayServicesGetBrightnessFunc?
    private var setBrightnessFn: DisplayServicesSetBrightnessFunc?

    fileprivate var eventTapPort: CFMachPort? = nil
    fileprivate var runLoopSource: CFRunLoopSource? = nil

    private init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let symGet = dlsym(handle, "DisplayServicesGetBrightness") {
                self.getBrightnessFn = unsafeBitCast(symGet, to: DisplayServicesGetBrightnessFunc.self)
            }
            if let symSet = dlsym(handle, "DisplayServicesSetBrightness") {
                self.setBrightnessFn = unsafeBitCast(symSet, to: DisplayServicesSetBrightnessFunc.self)
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

    /// Begins monitoring volume and display brightness changes and sets up the media key interceptor.
    public func startMonitoring() {
        guard !isInitialized else { return }
        let (vol, mute) = readCurrentAudioState()
        self.lastVolume = vol
        self.lastMute = mute
        self.lastBrightness = readCurrentBrightness()
        self.isInitialized = true

        setupAudioListener()
        startPolling()
        updateInterceptionState()
    }

    /// Stops monitoring, unhooks all CoreAudio property listeners, disables event taps, and restores normal macOS behavior.
    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil

        removeDeviceListener()
        removeDefaultDeviceListener()
        stopEventTap()

        isInitialized = false
    }

    // MARK: - Event Tap Interception (Hides Native macOS OSD Pill)

    public func updateInterceptionState() {
        if ObeliskSettings.shared.replaceSystemVolumeHUD && AXIsProcessTrusted() {
            startEventTap()
        } else {
            stopEventTap()
        }
    }

    private func startEventTap() {
        guard eventTapPort == nil else { return }

        // Event type 14 is CGEventType.systemDefined (raw value 14)
        let mask = CGEventMask(1 << 14)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: systemMediaKeyTapCallback,
            userInfo: selfPtr
        ) else {
            return
        }

        self.eventTapPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopEventTap() {
        if let tap = eventTapPort {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                self.runLoopSource = nil
            }
            CFMachPortInvalidate(tap)
            self.eventTapPort = nil
        }
    }

    /// Handles keyboard media key actions (Volume Up/Down, Mute, Brightness Up/Down)
    public func handleMediaKey(keyCode: Int32, isFineGrained: Bool) {
        let step: Float = isFineGrained ? (1.0 / 64.0) : (1.0 / 16.0)

        switch keyCode {
        case 0: // Sound Up (NX_KEYTYPE_SOUND_UP)
            let (currentVol, currentMute) = readCurrentAudioState()
            if currentMute {
                setMute(false)
            }
            let newVol = min(1.0, currentVol + step)
            setVolume(newVol)
            let (devName, isHP) = readOutputDeviceNameAndType()
            HardwareTelemetryService.shared.triggerTransientHUD(
                .volume(level: Double(newVol), isMuted: false, deviceName: devName, isHeadphones: isHP),
                duration: 1.8
            )

        case 1: // Sound Down (NX_KEYTYPE_SOUND_DOWN)
            let (currentVol, currentMute) = readCurrentAudioState()
            let newVol = max(0.0, currentVol - step)
            setVolume(newVol)
            let (devName, isHP) = readOutputDeviceNameAndType()
            HardwareTelemetryService.shared.triggerTransientHUD(
                .volume(level: Double(newVol), isMuted: currentMute, deviceName: devName, isHeadphones: isHP),
                duration: 1.8
            )

        case 7: // Mute (NX_KEYTYPE_MUTE)
            let (_, currentMute) = readCurrentAudioState()
            let newMute = !currentMute
            setMute(newMute)
            let (currentVol, _) = readCurrentAudioState()
            let (devName, isHP) = readOutputDeviceNameAndType()
            HardwareTelemetryService.shared.triggerTransientHUD(
                .volume(level: Double(currentVol), isMuted: newMute, deviceName: devName, isHeadphones: isHP),
                duration: 1.8
            )

        case 2: // Brightness Up (NX_KEYTYPE_BRIGHTNESS_UP)
            let currentB = readCurrentBrightness()
            let newB = min(1.0, currentB + step)
            setBrightness(newB)
            HardwareTelemetryService.shared.triggerTransientHUD(
                .brightness(level: Double(newB)),
                duration: 1.8
            )

        case 3: // Brightness Down (NX_KEYTYPE_BRIGHTNESS_DOWN)
            let currentB = readCurrentBrightness()
            let newB = max(0.0, currentB - step)
            setBrightness(newB)
            HardwareTelemetryService.shared.triggerTransientHUD(
                .brightness(level: Double(newB)),
                duration: 1.8
            )

        default:
            break
        }
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
                let (devName, isHP) = readOutputDeviceNameAndType()
                HardwareTelemetryService.shared.triggerTransientHUD(
                    .volume(level: Double(vol), isMuted: mute, deviceName: devName, isHeadphones: isHP),
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

    // MARK: - Audio Volume, Mute, & Device Helpers

    public func defaultOutputDeviceID() -> AudioDeviceID {
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

    public func readCurrentAudioState() -> (volume: Float32, isMuted: Bool) {
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

    public func setVolume(_ newVol: Float32) {
        let devID = defaultOutputDeviceID()
        guard devID != 0 else { return }

        var vol = max(0.0, min(1.0, newVol))
        let volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(devID, &volAddr, 0, nil, volSize, &vol)
        if status != noErr {
            volAddr.mSelector = kAudioDevicePropertyVolumeScalar
            _ = AudioObjectSetPropertyData(devID, &volAddr, 0, nil, volSize, &vol)
        }
        self.lastVolume = vol
    }

    public func setMute(_ muted: Bool) {
        let devID = defaultOutputDeviceID()
        guard devID != 0 else { return }

        var mute: UInt32 = muted ? 1 : 0
        let muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectSetPropertyData(devID, &muteAddr, 0, nil, muteSize, &mute)
        self.lastMute = muted
    }

    public static func isHeadphonesDevice(name: String) -> Bool {
        let lower = name.lowercased()
        let headphoneKeywords = [
            "airpod", "bud", "headphone", "headset", "earphone", "earpod",
            "in-ear", "over-ear", "iem", "wh-1000", "wf-1000", "qc35", "qc45",
            "quietcomfort", "shokz", "openrun", "aeropex", "freebuds", "liberty",
            "airfocus", "aerofit", "beats fit", "beats studio", "powerbeats", "solo"
        ]
        for kw in headphoneKeywords {
            if lower.contains(kw) { return true }
        }
        return false
    }

    public func readOutputDeviceNameAndType(for devID: AudioDeviceID? = nil) -> (name: String, isHeadphones: Bool) {
        let id = devID ?? defaultOutputDeviceID()
        guard id != 0 else { return ("Volume", false) }

        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameString: CFString? = nil
        var nameSize = UInt32(MemoryLayout<CFString?>.size)
        var status = withUnsafeMutablePointer(to: &nameString) { ptr in
            AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, ptr)
        }
        if status != noErr || nameString == nil {
            nameAddr.mSelector = kAudioObjectPropertyName
            status = withUnsafeMutablePointer(to: &nameString) { ptr in
                AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, ptr)
            }
        }
        let rawName = nameString as String? ?? ""
        let cleanName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = cleanName.isEmpty ? "Volume" : cleanName

        let isHP = Self.isHeadphonesDevice(name: name)
        return (name, isHP)
    }

    // MARK: - Display Brightness Helper

    public func readCurrentBrightness() -> Float {
        guard let fn = getBrightnessFn else { return -1 }
        var brightness: Float = 0
        let status = fn(CGMainDisplayID(), &brightness)
        return (status == 0) ? max(0, min(1.0, brightness)) : -1
    }

    public func setBrightness(_ newBrightness: Float) {
        guard let fn = setBrightnessFn else { return }
        let clamped = max(0.0, min(1.0, newBrightness))
        _ = fn(CGMainDisplayID(), clamped)
        self.lastBrightness = clamped
    }
}

// MARK: - Global C-Function Callback for Event Tap (Intercepts Media Keys)

private func systemMediaKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<SystemVolumeAndBrightnessMonitor>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Task { @MainActor in
            if let tap = monitor.eventTapPort {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == CGEventType(rawValue: 14) /* systemDefined */ else {
        return Unmanaged.passUnretained(event)
    }

    guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
        return Unmanaged.passUnretained(event)
    }

    let data1 = nsEvent.data1
    let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
    let keyFlags = (data1 & 0x0000FFFF)
    let keyState = (keyFlags & 0xFF00) >> 8
    let isKeyDown = (keyState == 0x0A)

    // KeyCodes from IOKit ev_keymap.h:
    // 0: NX_KEYTYPE_SOUND_UP
    // 1: NX_KEYTYPE_SOUND_DOWN
    // 2: NX_KEYTYPE_BRIGHTNESS_UP
    // 3: NX_KEYTYPE_BRIGHTNESS_DOWN
    // 7: NX_KEYTYPE_MUTE
    guard keyCode == 0 || keyCode == 1 || keyCode == 2 || keyCode == 3 || keyCode == 7 else {
        return Unmanaged.passUnretained(event)
    }

    if isKeyDown {
        let isShift = nsEvent.modifierFlags.contains(.shift)
        let isOption = nsEvent.modifierFlags.contains(.option)
        let isFineGrained = isShift && isOption

        Task { @MainActor in
            monitor.handleMediaKey(keyCode: keyCode, isFineGrained: isFineGrained)
        }
    }

    // Swallows the event so macOS WindowServer / BezelUI never triggers the floating OSD pill!
    return nil
}
