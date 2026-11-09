import Foundation
import SwiftUI
import Combine
import Darwin
import IOKit.ps

/// Represents a transient Dynamic Island HUD notification displayed briefly when the notch is collapsed or expanded.
public enum NotchTransientHUD: Equatable, Hashable {
    case deviceConnected(name: String, iconName: String, statusText: String)
    case deviceDisconnected(name: String, iconName: String, statusText: String)
    case battery(percentage: Int, isCharging: Bool, statusText: String)
    case volume(level: Double, isMuted: Bool)
    case brightness(level: Double)
    case capsLock(isOn: Bool)
}

/// Monitors real-time Apple Silicon hardware telemetry (CPU load, Unified Memory, SSD disk capacity,
/// thermal state, and MagSafe/battery power state) and dispatches compact notch HUD animations.
@MainActor
public final class HardwareTelemetryService: ObservableObject {
    public static let shared = HardwareTelemetryService()

    // MARK: - Published Telemetry State
    @Published public var cpuUsagePercent: Double = 8.0
    @Published public var memoryUsedGB: Double = 8.0
    @Published public var memoryTotalGB: Double = 16.0
    @Published public var memoryUsagePercent: Double = 50.0
    @Published public var memoryPressureLabel: String = "Normal"

    @Published public var diskUsedGB: Double = 120.0
    @Published public var diskTotalGB: Double = 512.0
    @Published public var diskFreeGB: Double = 392.0
    @Published public var diskUsagePercent: Double = 23.0

    @Published public var thermalStateLabel: String = "Nominal"

    // MARK: - Published Battery & MagSafe State
    @Published public var batteryPercentage: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var isPluggedIn: Bool = false
    @Published public var timeRemainingMinutes: Int? = nil
    @Published public var batteryStatusText: String = "Charged"
    @Published public var batteryHealthPercent: Int = 100
    @Published public var batteryCycleCount: Int = 0
    public var lastChargerConnectionTime: Date = .distantPast
    public var lastChargerDisconnectionTime: Date = .distantPast

    // MARK: - Transient Compact Notch HUD State
    @Published public var activeTransientHUD: NotchTransientHUD? = nil

    private var telemetryTimer: Timer?
    private var powerRunLoopSource: CFRunLoopSource?
    private var previousCPUTicks: [Int32] = []
    private var hasInitializedPowerState: Bool = false
    private var lastLowBatteryAlertLevel: Int = 100
    private var hudDismissWorkItem: DispatchWorkItem?

    private init() {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        self.memoryTotalGB = Double(totalBytes) / 1_073_741_824.0

        updateAllMetrics(isInitial: true)
        fetchSmartBatteryHealth()
        setupPowerSourceNotification()
        startTelemetryTimer()
    }

    /// Displays a transient HUD animation and text inside the notch body (flanking camera), whether collapsed or expanded.
    public func triggerTransientHUD(_ hud: NotchTransientHUD, duration: TimeInterval = 1.8) {
        // Protect higher-priority device connection HUD from being overwritten by volume/brightness
        if let active = self.activeTransientHUD {
            switch active {
            case .deviceConnected, .deviceDisconnected:
                if case .volume = hud { return }
                if case .brightness = hud { return }
            default:
                break
            }
        }

        hudDismissWorkItem?.cancel()

        let isSnappy: Bool
        switch hud {
        case .volume, .brightness, .capsLock:
            isSnappy = true
        default:
            isSnappy = false
        }

        // Apple signature spring: fluid, organic, slightly bouncy response like native iOS/macOS Dynamic Island
        let springAnimation: Animation = isSnappy
            ? .spring(response: 0.32, dampingFraction: 0.74)
            : .spring(response: 0.36, dampingFraction: 0.82)

        withAnimation(springAnimation) {
            self.activeTransientHUD = hud
            if !WindowManager.shared.isExpanded {
                WindowManager.shared.updateCompactWidth(animated: false)
            }
        }

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                let dismissAnimation: Animation = isSnappy
                    ? .spring(response: 0.28, dampingFraction: 0.84)
                    : .spring(response: 0.34, dampingFraction: 0.85)

                withAnimation(dismissAnimation) {
                    self.activeTransientHUD = nil
                    if !WindowManager.shared.isExpanded {
                        WindowManager.shared.updateCompactWidth(animated: false)
                    }
                }
            }
        }
        hudDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    /// Dismisses any active transient HUD immediately and cancels pending dismiss timers.
    public func dismissTransientHUD(animated: Bool = true) {
        hudDismissWorkItem?.cancel()
        hudDismissWorkItem = nil

        guard activeTransientHUD != nil else { return }

        let update = {
            self.activeTransientHUD = nil
            if !WindowManager.shared.isExpanded {
                WindowManager.shared.updateCompactWidth(animated: false)
            }
        }

        if animated {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                update()
            }
        } else {
            update()
        }
    }

    private func startTelemetryTimer() {
        telemetryTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAllMetrics(isInitial: false)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.telemetryTimer = timer
    }

    private func setupPowerSourceNotification() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let instance = Unmanaged<HardwareTelemetryService>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in
                instance.updateBatteryMetrics(isInitial: false)
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            self.powerRunLoopSource = source
        }
    }

    public func updateAllMetrics(isInitial: Bool = false) {
        updateCPUMetrics()
        updateMemoryMetrics()
        updateDiskMetrics()
        updateThermalState()
        updateBatteryMetrics(isInitial: isInitial)
    }

    // MARK: - CPU Load Calculation via Mach `host_processor_info`

    private func updateCPUMetrics() {
        var numCPUsU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUsU,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else { return }
        defer {
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let count = Int(numCPUInfo)
        var currentTicks = [Int32](repeating: 0, count: count)
        for i in 0..<count {
            currentTicks[i] = info[i]
        }

        if previousCPUTicks.count == count {
            var totalUserAndSys: Double = 0
            var totalAll: Double = 0
            let cpuCount = Int(numCPUsU)
            for cpu in 0..<cpuCount {
                let base = cpu * Int(CPU_STATE_MAX)
                let userDiff = Double(currentTicks[base + Int(CPU_STATE_USER)] - previousCPUTicks[base + Int(CPU_STATE_USER)])
                let sysDiff = Double(currentTicks[base + Int(CPU_STATE_SYSTEM)] - previousCPUTicks[base + Int(CPU_STATE_SYSTEM)])
                let niceDiff = Double(currentTicks[base + Int(CPU_STATE_NICE)] - previousCPUTicks[base + Int(CPU_STATE_NICE)])
                let idleDiff = Double(currentTicks[base + Int(CPU_STATE_IDLE)] - previousCPUTicks[base + Int(CPU_STATE_IDLE)])

                let active = max(0, userDiff + sysDiff + niceDiff)
                let total = max(1, active + max(0, idleDiff))
                totalUserAndSys += active
                totalAll += total
            }
            if totalAll > 0 {
                let pct = min(100.0, max(0.0, (totalUserAndSys / totalAll) * 100.0))
                self.cpuUsagePercent = pct
            }
        }
        self.previousCPUTicks = currentTicks
    }

    // MARK: - Unified Memory Calculation via Mach `host_statistics64`

    private func updateMemoryMetrics() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let pageBytes = Double(pageSize)

        let activeBytes = Double(stats.active_count) * pageBytes
        let wiredBytes = Double(stats.wire_count) * pageBytes
        let compressedBytes = Double(stats.compressor_page_count) * pageBytes
        let usedBytes = activeBytes + wiredBytes + compressedBytes

        let usedGB = usedBytes / 1_073_741_824.0
        self.memoryUsedGB = min(memoryTotalGB, max(0.5, usedGB))
        self.memoryUsagePercent = min(100.0, max(1.0, (self.memoryUsedGB / max(1.0, memoryTotalGB)) * 100.0))

        if memoryUsagePercent >= 85 {
            self.memoryPressureLabel = "High"
        } else if memoryUsagePercent >= 70 {
            self.memoryPressureLabel = "Elevated"
        } else {
            self.memoryPressureLabel = "Normal"
        }
    }

    // MARK: - SSD Storage Metrics

    private func updateDiskMetrics() {
        let rootURL = URL(fileURLWithPath: "/")
        if let values = try? rootURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            let total = Double(values.volumeTotalCapacity ?? 0) / 1_000_000_000.0
            let free = Double(values.volumeAvailableCapacityForImportantUsage ?? 0) / 1_000_000_000.0
            if total > 0 {
                self.diskTotalGB = total
                self.diskFreeGB = free
                self.diskUsedGB = max(0, total - free)
                self.diskUsagePercent = min(100.0, max(0.0, (self.diskUsedGB / total) * 100.0))
            }
        }
    }

    // MARK: - Thermal State

    private func updateThermalState() {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            self.thermalStateLabel = "Nominal"
        case .fair:
            self.thermalStateLabel = "Fair"
        case .serious:
            self.thermalStateLabel = "Warm"
        case .critical:
            self.thermalStateLabel = "Hot"
        @unknown default:
            self.thermalStateLabel = "Nominal"
        }
    }

    // MARK: - Battery & MagSafe Power State via IOKit

    private func updateBatteryMetrics(isInitial: Bool) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let firstSource = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: Any] else {
            return
        }

        let currentCap = (desc[kIOPSCurrentCapacityKey as String] as? Int) ?? 100
        let maxCap = max(1, (desc[kIOPSMaxCapacityKey as String] as? Int) ?? 100)
        let pct = Int(round((Double(currentCap) / Double(maxCap)) * 100.0))

        let powerState = (desc[kIOPSPowerSourceStateKey as String] as? String) ?? ""
        let pluggedIn = (powerState == (kIOPSACPowerValue as String))
        let charging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false

        var timeMins: Int? = nil
        if charging {
            if let ttf = desc[kIOPSTimeToFullChargeKey as String] as? Int, ttf > 0 && ttf < 1500 {
                timeMins = ttf
            }
        } else if !pluggedIn {
            if let tte = desc[kIOPSTimeToEmptyKey as String] as? Int, tte > 0 && tte < 1500 {
                timeMins = tte
            }
        }

        let statusStr: String
        if charging {
            if let mins = timeMins {
                let h = mins / 60
                let m = mins % 60
                let timeFormatted = h > 0 ? "\(h)h \(m)m" : "\(m)m"
                statusStr = "\(pct)% • \(timeFormatted) until full"
            } else if pct >= 100 {
                statusStr = "100% • Fully Charged"
            } else {
                statusStr = "\(pct)% • Calculating..."
            }
        } else if pluggedIn {
            statusStr = "\(pct)% • Power Adapter"
        } else {
            if let mins = timeMins {
                let h = mins / 60
                let m = mins % 60
                statusStr = "\(pct)% • \(h > 0 ? "\(h)h \(m)m" : "\(m)m") Left"
            } else {
                statusStr = "\(pct)% • On Battery"
            }
        }

        let previousPluggedIn = self.isPluggedIn
        let previousCharging = self.isCharging

        self.batteryPercentage = pct
        self.isPluggedIn = pluggedIn
        self.isCharging = charging
        self.timeRemainingMinutes = timeMins
        self.batteryStatusText = statusStr

        if hasInitializedPowerState && !isInitial {
            if pluggedIn != previousPluggedIn || charging != previousCharging {
                if previousPluggedIn && !pluggedIn {
                    self.lastChargerDisconnectionTime = Date()
                    triggerTransientHUD(
                        .battery(
                            percentage: pct,
                            isCharging: false,
                            statusText: "Disconnected"
                        ),
                        duration: 3.5
                    )
                } else if pluggedIn {
                    self.lastChargerConnectionTime = Date()
                    triggerTransientHUD(
                        .battery(
                            percentage: pct,
                            isCharging: true,
                            statusText: statusStr
                        ),
                        duration: 3.6
                    )
                }
            } else if !pluggedIn && pct <= 20 && lastLowBatteryAlertLevel > 20 {
                triggerTransientHUD(
                    .battery(
                        percentage: pct,
                        isCharging: false,
                        statusText: "Low Battery"
                    ),
                    duration: 4.0
                )
            }
        }

        lastLowBatteryAlertLevel = pct
        hasInitializedPowerState = true
    }

    private func fetchSmartBatteryHealth() {
        Task.detached(priority: .utility) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
            proc.arguments = ["-rn", "AppleSmartBattery", "-d", "1"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            do {
                try proc.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                if let out = String(data: data, encoding: .utf8) {
                    var cycles = 0
                    var nominalCap: Double = 0
                    var designCap: Double = 0

                    for line in out.components(separatedBy: .newlines) {
                        if line.contains("\"CycleCount\" =") {
                            let parts = line.components(separatedBy: "=")
                            if let val = Int(parts.last?.trimmingCharacters(in: .whitespaces) ?? "") {
                                cycles = val
                            }
                        } else if line.contains("\"NominalChargeCapacity\" =") {
                            let parts = line.components(separatedBy: "=")
                            if let val = Double(parts.last?.trimmingCharacters(in: .whitespaces) ?? "") {
                                nominalCap = val
                            }
                        } else if line.contains("\"DesignCapacity\" =") && !line.contains("Fed") {
                            let parts = line.components(separatedBy: "=")
                            if let val = Double(parts.last?.trimmingCharacters(in: .whitespaces) ?? "") {
                                designCap = val
                            }
                        }
                    }

                    let health: Int
                    if nominalCap > 0 && designCap > 0 {
                        health = min(100, max(50, Int(round((nominalCap / designCap) * 100.0))))
                    } else {
                        health = 100
                    }

                    let finalCycles = cycles
                    await MainActor.run {
                        HardwareTelemetryService.shared.batteryCycleCount = finalCycles
                        HardwareTelemetryService.shared.batteryHealthPercent = health
                    }
                }
            } catch {}
        }
    }
}
