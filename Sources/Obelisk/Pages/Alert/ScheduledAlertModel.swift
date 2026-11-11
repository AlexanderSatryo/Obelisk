import Foundation

/// Defines how often a scheduled alert should trigger.
public enum AlertRecurrence: String, Codable, CaseIterable, Identifiable {
    case weekdays = "Weekdays (Mon - Fri)"
    case daily = "Daily (Every day)"
    case weekends = "Weekends (Sat - Sun)"
    case once = "Once (Specific Date)"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .weekdays: return "Mon - Fri"
        case .daily: return "Daily"
        case .weekends: return "Sat - Sun"
        case .once: return "One-time"
        }
    }
}

/// Represents one scheduled reminder alert displayed on the Obelisk notch.
public struct ScheduledAlertItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var time: String // "HH:mm" 24-hour format
    public var recurrence: AlertRecurrence
    public var specificDate: Date?
    public var isEnabled: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        time: String,
        recurrence: AlertRecurrence = .weekdays,
        specificDate: Date? = nil,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.recurrence = recurrence
        self.specificDate = specificDate
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    /// Evaluates whether this alert should fire for the given date and time.
    public func shouldTrigger(at date: Date, calendar: Calendar = Calendar.current) -> Bool {
        guard isEnabled else { return false }

        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let targetHour = Int(parts[0]),
              let targetMinute = Int(parts[1]) else {
            return false
        }

        let comps = calendar.dateComponents([.hour, .minute, .weekday, .year, .month, .day], from: date)
        guard comps.hour == targetHour, comps.minute == targetMinute else {
            return false
        }

        let weekday = comps.weekday ?? 1 // 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat

        switch recurrence {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday)
        case .weekends:
            return weekday == 1 || weekday == 7
        case .once:
            guard let spec = specificDate else { return true }
            let specComps = calendar.dateComponents([.year, .month, .day], from: spec)
            return comps.year == specComps.year && comps.month == specComps.month && comps.day == specComps.day
        }
    }
}

