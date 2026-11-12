import AppKit
import Combine
import Foundation

/// Coordinates time-based scheduled reminder alerts, monitors system clock triggers,
/// and presents smooth transient notch animations when alerts fire.
@MainActor
public final class ScheduledAlertService: ObservableObject {
    public static let shared = ScheduledAlertService()

    @Published public var alerts: [ScheduledAlertItem] = []
    @Published public var activeAlert: ScheduledAlertItem? = nil
    @Published public var playChimeSound: Bool = true
    @Published public var alertDisplayDuration: TimeInterval = 8.0

    private var timer: AnyCancellable?
    private var lastFiredKeys: Set<String> = []
    private let storageKey = "obelisk_scheduled_alerts_v1"
    private let soundKey = "obelisk_scheduled_alerts_sound"

    public init() {
        self.playChimeSound = UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true
        loadAlerts()
        startClockMonitor()
    }

    // MARK: - Persistence

    public func loadAlerts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ScheduledAlertItem].self, from: data) {
            self.alerts = decoded
        } else {
            self.alerts = []
            saveAlerts()
        }
    }

    public func saveAlerts() {
        if let encoded = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    public func setPlayChimeSound(_ enabled: Bool) {
        self.playChimeSound = enabled
        UserDefaults.standard.set(enabled, forKey: soundKey)
    }

    // MARK: - Alert CRUD

    public func addAlert(title: String, time: String, recurrence: AlertRecurrence = .weekdays, specificDate: Date? = nil) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let item = ScheduledAlertItem(
            title: cleanTitle,
            time: time,
            recurrence: recurrence,
            specificDate: specificDate,
            isEnabled: true
        )
        alerts.append(item)
        saveAlerts()
    }

    public func updateAlert(_ item: ScheduledAlertItem) {
        if let idx = alerts.firstIndex(where: { $0.id == item.id }) {
            alerts[idx] = item
            saveAlerts()
        }
    }

    public func deleteAlert(id: UUID) {
        alerts.removeAll(where: { $0.id == id })
        saveAlerts()
    }

    public func toggleAlert(id: UUID) {
        if let idx = alerts.firstIndex(where: { $0.id == id }) {
            alerts[idx].isEnabled.toggle()
            saveAlerts()
        }
    }

    // MARK: - Clock Evaluation

    private func startClockMonitor() {
        // Poll every 2 seconds to reliably catch the minute turnover without CPU overhead
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.evaluateScheduledAlerts(at: now)
            }
    }

    private func evaluateScheduledAlerts(at now: Date) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        guard let y = comps.year, let m = comps.month, let d = comps.day,
              let h = comps.hour, let min = comps.minute else { return }

        let timeStampKey = String(format: "%04d-%02d-%02d-%02d:%02d", y, m, d, h, min)

        for alert in alerts where alert.isEnabled {
            let alertKey = "\(alert.id.uuidString)-\(timeStampKey)"
            if lastFiredKeys.contains(alertKey) {
                continue
            }

            if alert.shouldTrigger(at: now, calendar: cal) {
                lastFiredKeys.insert(alertKey)
                if alert.recurrence == .once {
                    if let idx = alerts.firstIndex(where: { $0.id == alert.id }) {
                        alerts[idx].isEnabled = false
                        saveAlerts()
                    }
                }
                triggerAlert(alert)
                break // Trigger one alert per tick
            }
        }

        // Clean up keys older than 2 hours to avoid unbounded set growth
        if lastFiredKeys.count > 100 {
            lastFiredKeys.removeAll()
        }
    }

    // MARK: - Presentation

    public func triggerAlert(_ alert: ScheduledAlertItem) {
        self.activeAlert = alert

        if playChimeSound {
            NSSound(named: "Ping")?.play()
        }

        let settings = ObeliskSettings.shared
        let mins = settings.scheduledAlertDismissMinutes
        let requireOK = settings.scheduledAlertRequireOK

        // If requireOK is true or mins == 0 (Until Dismissed), keep it visible up to 1 hour (or until OK button is clicked)
        let duration: TimeInterval = (requireOK || mins == 0)
            ? 3600.0
            : max(5.0, TimeInterval(mins * 60))

        // Ensure window receives mouse clicks on the standby notch
        WindowManager.shared.setIgnoresMouseEvents(false)

        // Trigger the notch expansion HUD
        HardwareTelemetryService.shared.triggerTransientHUD(
            .scheduledAlert(title: alert.title, time: alert.time),
            duration: duration
        )
    }

    /// Manual preview trigger for testing animations directly from the dashboard
    public func testTriggerAlert(_ alert: ScheduledAlertItem) {
        triggerAlert(alert)
    }

    public func dismissActiveAlert() {
        self.activeAlert = nil
        HardwareTelemetryService.shared.dismissTransientHUD()
    }
}

