import Foundation
import AppKit
import CoreGraphics

/// Monitors macOS Caps Lock state transitions in real time (via global event flag monitors
/// and unprivileged Quartz HID event source polling) and triggers transient Dynamic Island notch HUD notifications.
@MainActor
public final class CapsLockMonitorService: ObservableObject {
    public static let shared = CapsLockMonitorService()

    @Published public private(set) var isCapsLockOn: Bool = false

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pollTimer: Timer?
    private var isInitialized: Bool = false

    private init() {
        let initial = CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
            || NSEvent.modifierFlags.contains(.capsLock)
        self.isCapsLockOn = initial

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

    /// Starts real-time monitoring of Caps Lock state transitions.
    public func startMonitoring() {
        guard !isInitialized else { return }
        isInitialized = true

        let current = CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
            || NSEvent.modifierFlags.contains(.capsLock)
        self.isCapsLockOn = current

        // 1. Event-driven monitor (fires with 0ms latency when Accessibility is granted)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlagsChanged(event.modifierFlags.contains(.capsLock))
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleFlagsChanged(event.modifierFlags.contains(.capsLock))
            }
            return event
        }

        // 2. High-speed Quartz HID fallback polling (100ms / 10 FPS)
        // Requires ZERO permissions, works 100% reliably in background, sandbox, or without Accessibility!
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let state = CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
                if state != self.isCapsLockOn {
                    self.handleFlagsChanged(state)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }

    /// Stops monitoring and unregisters all event monitors and timers.
    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil

        if let g = globalMonitor {
            NSEvent.removeMonitor(g)
            globalMonitor = nil
        }
        if let l = localMonitor {
            NSEvent.removeMonitor(l)
            localMonitor = nil
        }
        isInitialized = false
    }

    private func handleFlagsChanged(_ newState: Bool) {
        guard newState != isCapsLockOn else { return }
        self.isCapsLockOn = newState

        let settings = ObeliskSettings.shared
        guard settings.showCapsLockHUD else { return }

        HardwareTelemetryService.shared.triggerTransientHUD(
            .capsLock(isOn: newState),
            duration: 1.6
        )
    }
}

