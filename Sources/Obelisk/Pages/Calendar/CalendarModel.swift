import Foundation
import SwiftUI

public struct CalendarItem: Identifiable, Sendable, Codable {
    public let id: UUID
    public let title: String
    public let time: String
    public let calendarName: String
    public let startDate: Date?
    public let endDate: Date?
    public let colorR: Double?
    public let colorG: Double?
    public let colorB: Double?

    public init(
        title: String,
        time: String,
        calendarName: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        colorR: Double? = nil,
        colorG: Double? = nil,
        colorB: Double? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.time = time
        self.calendarName = calendarName
        self.startDate = startDate
        self.endDate = endDate
        self.colorR = colorR
        self.colorG = colorG
        self.colorB = colorB
    }

    public var isPassed: Bool {
        let now = Date()
        if let end = endDate {
            return end <= now
        }
        if let start = startDate {
            // If no explicit end date is present, mark as passed 60 minutes after start time
            return start <= now.addingTimeInterval(-3600)
        }
        return false
    }

    public var calendarColor: Color {
        if let r = colorR, let g = colorG, let b = colorB {
            return Color(red: r, green: g, blue: b)
        }
        return Color(red: 0.25, green: 0.55, blue: 1.0)
    }
}
