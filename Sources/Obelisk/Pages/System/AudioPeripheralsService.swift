import Foundation
import Combine
import CoreAudio
import AudioToolbox
import IOBluetooth

/// Categorizes audio output hardware transport types.
public enum AudioTransportCategory: String {
    case builtInSpeaker = "Built-in"
    case wiredHeadphones = "Headphones"
    case bluetoothEarbuds = "Bluetooth"
    case usbAudio = "USB"
    case displayAudio = "Display"

    public var iconName: String {
        switch self {
        case .builtInSpeaker: return "laptopcomputer"
        case .wiredHeadphones: return "headphones"
        case .bluetoothEarbuds: return "earbuds"
        case .usbAudio: return "cable.connector"
        case .displayAudio: return "display"
        }
    }
}

/// Represents a unified selectable audio output route (either an active CoreAudio output or paired Bluetooth earbuds).
public struct AudioRouteOption: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let iconName: String
    public let isActive: Bool
    public let coreAudioID: AudioDeviceID?
    public let bluetoothAddress: String?
}

/// Manages CoreAudio output device routing for the Media Player speaker menu
/// and monitors Bluetooth/peripheral device connections to trigger the compact notch connection animation.
@MainActor
public final class AudioPeripheralsService: NSObject, ObservableObject {
    public static let shared = AudioPeripheralsService()

    // MARK: - Published Audio Output State
    @Published public var selectableRoutes: [AudioRouteOption] = []
    @Published public var currentOutputDeviceID: AudioDeviceID = 0
    @Published public var currentOutputDeviceName: String = "MacBook Pro Speakers"
    @Published public var isRoutePickerExpanded: Bool = false

    private var btConnectNotification: IOBluetoothUserNotification?
    private var btDisconnectNotifications: [IOBluetoothUserNotification] = []
    private var lastAnnouncedDeviceName: String = ""
    private var lastAnnouncedTime: Date = .distantPast
    private var lastAnnouncedDisconnectName: String = ""
    private var lastAnnouncedDisconnectTime: Date = .distantPast
    private var knownOutputDeviceNames: [AudioDeviceID: String] = [:]
    private let listenerQueue = DispatchQueue(label: "com.alxstry.obelisk.coreaudio.listener")

    private override init() {
        super.init()
        refreshAudioDevices()
        installCoreAudioListeners()
        registerBluetoothObservers()
    }

    // MARK: - CoreAudio & Paired Bluetooth Route Enumeration

    /// Refreshes the unified list of selectable audio output routes (active CoreAudio devices + paired Bluetooth earbuds).
    public func refreshAudioDevices() {
        let defaultOutID = getDefaultAudioDevice(isInput: false)
        self.currentOutputDeviceID = defaultOutID

        let allIDs = getAllAudioDeviceIDs()
        var routes: [AudioRouteOption] = []
        var seenNamesLower: Set<String> = []
        var currentMap: [AudioDeviceID: String] = [:]

        for devID in allIDs {
            guard hasOutputStreams(devID),
                  let name = getDeviceName(devID),
                  !name.contains("CADefaultDeviceAggregate"),
                  !name.contains("ZoomAudioDevice") else {
                continue
            }

            currentMap[devID] = name
            let category = getDeviceTransportCategory(devID, name: name)
            let isDef = (devID == defaultOutID)
            if isDef {
                self.currentOutputDeviceName = name
            }

            let icon = Self.resolveDeviceIcon(for: name, fallback: category.iconName)
            routes.append(
                AudioRouteOption(
                    id: "ca_\(devID)",
                    name: name,
                    iconName: icon,
                    isActive: isDef,
                    coreAudioID: devID,
                    bluetoothAddress: nil
                )
            )
            seenNamesLower.insert(name.lowercased())
        }

        // Detect any disconnected peripherals when a known non-speaker device is removed
        if !knownOutputDeviceNames.isEmpty {
            for (oldID, oldName) in knownOutputDeviceNames where currentMap[oldID] == nil {
                let lower = oldName.lowercased()
                if !lower.contains("speaker") && !lower.contains("macbook") && !lower.contains("display") {
                    let icon = Self.resolveDeviceIcon(for: oldName)
                    announceDisconnectedDevice(name: oldName, icon: icon)
                }
            }
        }
        self.knownOutputDeviceNames = currentMap

        // Only connected audio output devices are selectable (disconnected Bluetooth devices are omitted)
        self.selectableRoutes = routes
    }

    /// Switches audio output to the selected route, automatically opening a Bluetooth connection if needed.
    public func selectRoute(_ route: AudioRouteOption) {
        if let caID = route.coreAudioID {
            selectOutputDevice(caID)
        } else if let btAddr = route.bluetoothAddress {
            Task.detached(priority: .userInitiated) {
                if let btDevice = IOBluetoothDevice(addressString: btAddr) {
                    if !btDevice.isConnected() {
                        btDevice.openConnection()
                    }
                }
                // Wait briefly for CoreAudio to register the newly connected Bluetooth output stream, then select it
                for _ in 0..<8 {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    let switched = await MainActor.run { () -> Bool in
                        AudioPeripheralsService.shared.refreshAudioDevices()
                        if let match = AudioPeripheralsService.shared.selectableRoutes.first(where: {
                            $0.coreAudioID != nil && $0.name.localizedCaseInsensitiveContains(route.name)
                        }), let targetID = match.coreAudioID {
                            AudioPeripheralsService.shared.selectOutputDevice(targetID)
                            return true
                        }
                        return false
                    }
                    if switched { break }
                }
            }
        }
    }

    /// Switches the macOS system default audio output device instantaneously.
    public func selectOutputDevice(_ deviceID: AudioDeviceID) {
        var mutableID = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)

        var defaultOutAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutAddress,
            0,
            nil,
            size,
            &mutableID
        )

        var systemOutAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &systemOutAddress,
            0,
            nil,
            size,
            &mutableID
        )

        refreshAudioDevices()
    }

    public static func resolveDeviceIcon(for name: String, fallback: String = "earbuds") -> String {
        let lower = name.lowercased()
        if lower.contains("buds") || lower.contains("galaxy") || lower.contains("wf-") {
            return "earbuds"
        } else if lower.contains("airpods max") || lower.contains("wh-") {
            return "headphones"
        } else if lower.contains("airpods") {
            return "airpodspro"
        } else if lower.contains("headphone") {
            return "headphones"
        } else if lower.contains("mouse") || lower.contains("trackpad") {
            return "magicmouse.fill"
        } else if lower.contains("keyboard") {
            return "keyboard.fill"
        }
        return fallback
    }

    // MARK: - Real-Time Bluetooth & Audio Connection / Disconnection HUD

    private func registerBluetoothObservers() {
        btConnectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(handleBluetoothDeviceConnected(_:device:))
        )

        // Register disconnect listeners on all currently connected paired Bluetooth devices
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for dev in paired where dev.isConnected() {
                registerDisconnectObserver(for: dev)
            }
        }
    }

    private func registerDisconnectObserver(for device: IOBluetoothDevice) {
        if let note = device.register(forDisconnectNotification: self, selector: #selector(handleBluetoothDeviceDisconnected(_:device:))) {
            btDisconnectNotifications.append(note)
        }
    }

    @objc private func handleBluetoothDeviceConnected(_ notification: IOBluetoothUserNotification?, device: IOBluetoothDevice?) {
        guard let dev = device else { return }
        registerDisconnectObserver(for: dev)
        let name = dev.nameOrAddress ?? "Bluetooth Device"
        let icon = Self.resolveDeviceIcon(for: name)

        announceConnectedDevice(name: name, icon: icon)
        refreshAudioDevices()
    }

    @objc private func handleBluetoothDeviceDisconnected(_ notification: IOBluetoothUserNotification?, device: IOBluetoothDevice?) {
        guard let dev = device else { return }
        let name = dev.nameOrAddress ?? "Bluetooth Device"
        let icon = Self.resolveDeviceIcon(for: name)

        announceDisconnectedDevice(name: name, icon: icon)
        refreshAudioDevices()
    }

    public func announceConnectedDevice(name: String, icon: String) {
        let now = Date()
        if name == lastAnnouncedDeviceName && now.timeIntervalSince(lastAnnouncedTime) < 4.0 {
            return
        }
        lastAnnouncedDeviceName = name
        lastAnnouncedTime = now

        HardwareTelemetryService.shared.triggerTransientHUD(
            .deviceConnected(
                name: name,
                iconName: icon,
                statusText: "Connected"
            ),
            duration: 3.5
        )
    }

    public func announceDisconnectedDevice(name: String, icon: String) {
        let now = Date()
        if name == lastAnnouncedDisconnectName && now.timeIntervalSince(lastAnnouncedDisconnectTime) < 4.0 {
            return
        }
        lastAnnouncedDisconnectName = name
        lastAnnouncedDisconnectTime = now

        HardwareTelemetryService.shared.triggerTransientHUD(
            .deviceDisconnected(
                name: name,
                iconName: icon,
                statusText: "Disconnected"
            ),
            duration: 3.5
        )
    }

    private func installCoreAudioListeners() {
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, listenerQueue) { _, _ in
            Task { @MainActor in
                AudioPeripheralsService.shared.refreshAudioDevices()
            }
        }

        var defaultOutAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutAddr, listenerQueue) { _, _ in
            Task { @MainActor in
                let prevID = AudioPeripheralsService.shared.currentOutputDeviceID
                AudioPeripheralsService.shared.refreshAudioDevices()
                let newID = AudioPeripheralsService.shared.currentOutputDeviceID
                if prevID != 0 && newID != prevID,
                   let activeItem = AudioPeripheralsService.shared.selectableRoutes.first(where: { $0.coreAudioID == newID }),
                   !activeItem.name.localizedCaseInsensitiveContains("Speakers") {
                    AudioPeripheralsService.shared.announceConnectedDevice(
                        name: activeItem.name,
                        icon: activeItem.iconName
                    )
                }
            }
        }
    }

    // MARK: - Low-Level CoreAudio Helpers

    private func getDefaultAudioDevice(isInput: Bool) -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    private func getAllAudioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return []
        }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids)
        return ids
    }

    private func hasOutputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        return status == noErr && size > 0
    }

    private func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
        }
        return status == noErr ? (name as String) : nil
    }

    private func getDeviceTransportCategory(_ deviceID: AudioDeviceID, name: String) -> AudioTransportCategory {
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)

        let lower = name.lowercased()
        if transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE || lower.contains("buds") || lower.contains("airpods") {
            return .bluetoothEarbuds
        } else if lower.contains("headphone") {
            return .wiredHeadphones
        } else if transport == kAudioDeviceTransportTypeUSB {
            return .usbAudio
        } else if transport == kAudioDeviceTransportTypeHDMI || transport == kAudioDeviceTransportTypeDisplayPort {
            return .displayAudio
        }
        return .builtInSpeaker
    }
}
