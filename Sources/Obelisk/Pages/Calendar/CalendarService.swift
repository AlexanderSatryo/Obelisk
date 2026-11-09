import Foundation
import AppKit
import Combine
import SwiftUI
import EventKit

@MainActor
public final class CalendarService: ObservableObject {
    public static let shared = CalendarService()

    @Published public var events: [CalendarItem] = []
    @Published public var isLoading: Bool = false
    @Published public var isCalendarExpanded: Bool = false

    private static let cacheKey = "obelisk_cached_calendar_events_v5"
    private var lastFetchDate: Date? = nil

    private init() {
        let cached = CalendarService.loadFromCache()
        self.events = cached
        self.isLoading = cached.isEmpty
        fetchAgenda(force: true)
    }

    public func fetchAgenda(force: Bool = false) {
        if !force, let last = lastFetchDate, Date().timeIntervalSince(last) < 90 {
            return
        }

        if events.isEmpty {
            isLoading = true
        }

        Task { @MainActor [weak self] in
            let items = await CalendarService.queryCalendarEvents()
            guard let self = self else { return }
            if !items.isEmpty {
                self.events = items
                self.saveToCache(items)
            }
            self.lastFetchDate = Date()
            self.isLoading = false
        }
    }

    /// Returns strictly upcoming events that have NOT already ended or passed.
    public var upcomingEvents: [CalendarItem] {
        return events.filter { !$0.isPassed }
    }

    /// Returns events for a specific day. If `day` is today and `includePassed` is false,
    /// events that already ended earlier today are excluded.
    public func events(on day: Date, includePassed: Bool = false) -> [CalendarItem] {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(day)
        let startOfDay = calendar.startOfDay(for: day)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        return events.filter { item in
            guard let s = item.startDate else { return false }
            let e = item.endDate ?? s.addingTimeInterval(3600)
            guard s < endOfDay && e >= startOfDay else { return false }
            if isToday && !includePassed {
                return !item.isPassed
            }
            return true
        }
    }

    public func hasEvents(on day: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return false }

        return events.contains { item in
            guard let s = item.startDate else { return false }
            let e = item.endDate ?? s.addingTimeInterval(3600)
            return s < endOfDay && e >= startOfDay
        }
    }

    /// Returns true if the day is a weekend (Saturday / Sunday) or a recognized public/national holiday / Hari Raya ("Tanggal Merah").
    public func isRedDay(on day: Date) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: day)
        // Saturday (7) and Sunday (1) are both "tanggal merah" in weekend convention
        if weekday == 1 || weekday == 7 {
            return true
        }
        return isHoliday(on: day)
    }

    /// Returns true if the day is a recognized national holiday or Hari Raya.
    public func isHoliday(on day: Date) -> Bool {
        let cal = Calendar.current
        let dayEvents = events(on: day, includePassed: true)
        for ev in dayEvents {
            let cName = ev.calendarName.lowercased()
            let t = ev.title.lowercased()
            if cName.contains("holiday") || cName.contains("libur") || cName.contains("national") || cName.contains("raya") {
                return true
            }
            if t.contains("holiday") || t.contains("libur") || t.contains("cuti") || t.contains("hari raya") || t.contains("tahun baru") || t.contains("wafat") || t.contains("kenaikan") || t.contains("natal") || t.contains("pancasila") || t.contains("kemerdekaan") || t.contains("nyepi") || t.contains("imlek") || t.contains("waisak") || t.contains("isra") || t.contains("idul") || t.contains("easter") || t.contains("paskah") || t.contains("christmas") || t.contains("maulid") || t.contains("muharram") {
                return true
            }
        }

        let comps = cal.dateComponents([.year, .month, .day], from: day)
        guard let month = comps.month, let d = comps.day else { return false }

        // Fixed Indonesian / international national holidays
        if month == 1 && d == 1 { return true }   // Tahun Baru Masehi / New Year
        if month == 5 && d == 1 { return true }   // Hari Buruh / Labor Day
        if month == 6 && d == 1 { return true }   // Hari Lahir Pancasila
        if month == 8 && d == 17 { return true }  // Hari Kemerdekaan RI (17 Agustus)
        if month == 12 && d == 25 { return true } // Hari Raya Natal

        // Variable Indonesian national holidays & Hari Raya (2025, 2026, 2027)
        if let year = comps.year {
            if year == 2026 {
                let h2026: Set<String> = [
                    "1-16", // Isra Miraj Nabi Muhammad SAW
                    "2-17", // Tahun Baru Imlek 2577 Kongzili
                    "3-19", "3-20", "3-21", "3-22", "3-23", "3-24", // Hari Raya Idul Fitri 1447 H & Cuti Bersama
                    "3-21", // Hari Suci Nyepi Tahun Baru Saka 1948
                    "4-3",  // Wafat Yesus Kristus (Good Friday)
                    "4-5",  // Paskah
                    "5-14", // Kenaikan Yesus Kristus
                    "5-27", "5-28", // Hari Raya Idul Adha 1447 H & Cuti Bersama
                    "5-31", "6-1",  // Hari Raya Waisak 2570 BE
                    "6-16", // 1 Muharram / Tahun Baru Islam 1448 H
                    "8-25", // Maulid Nabi Muhammad SAW
                    "12-24", "12-25", "12-26" // Hari Raya Natal & Cuti Bersama
                ]
                if h2026.contains("\(month)-\(d)") { return true }
            } else if year == 2025 {
                let h2025: Set<String> = [
                    "1-1",  // Tahun Baru
                    "1-27", // Isra Miraj
                    "1-28", "1-29", // Tahun Baru Imlek
                    "3-28", "3-29", // Hari Suci Nyepi
                    "3-30", "3-31", "4-1", "4-2", // Hari Raya Idul Fitri
                    "4-18", // Wafat Yesus Kristus
                    "4-20", // Paskah
                    "5-1",  // Hari Buruh
                    "5-12", "5-13", // Hari Raya Waisak
                    "5-29", "5-30", // Kenaikan Yesus Kristus
                    "6-1",  // Hari Lahir Pancasila
                    "6-6",  // Hari Raya Idul Adha
                    "6-27", // 1 Muharam Tahun Baru Islam
                    "8-17", // Hari Kemerdekaan RI
                    "9-5",  // Maulid Nabi Muhammad SAW
                    "12-25", "12-26" // Hari Raya Natal
                ]
                if h2025.contains("\(month)-\(d)") { return true }
            } else if year == 2027 {
                let h2027: Set<String> = [
                    "1-1",  // Tahun Baru
                    "1-6",  // Isra Miraj
                    "2-6",  // Tahun Baru Imlek
                    "3-10", "3-11", // Hari Raya Idul Fitri
                    "3-26", // Wafat Yesus Kristus
                    "3-28", // Paskah
                    "5-1",  // Hari Buruh
                    "5-6",  // Kenaikan Yesus Kristus
                    "5-16", // Hari Raya Idul Adha
                    "5-20", // Hari Raya Waisak
                    "6-1",  // Hari Lahir Pancasila
                    "6-6",  // Tahun Baru Islam
                    "8-15", // Maulid Nabi Muhammad SAW
                    "8-17", // Hari Kemerdekaan RI
                    "12-25" // Hari Raya Natal
                ]
                if h2027.contains("\(month)-\(d)") { return true }
            }
        }

        return false
    }

    public func eventColor(on day: Date) -> Color? {
        let dayEvents = events(on: day, includePassed: true)
        return dayEvents.first?.calendarColor
    }

    private func saveToCache(_ items: [CalendarItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: CalendarService.cacheKey)
        } catch {
            // cache encoding failure ignored
        }
    }

    private static func loadFromCache() -> [CalendarItem] {
        guard let data = UserDefaults.standard.data(forKey: CalendarService.cacheKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([CalendarItem].self, from: data)
        } catch {
            return []
        }
    }

    private static func queryCalendarEvents() async -> [CalendarItem] {
        await Task.detached(priority: .userInitiated) {
            // 1. Silent native EventKit query (direct SQLite access via calaccessd, never launches Calendar.app)
            let store = EKEventStore()
            let status = EKEventStore.authorizationStatus(for: .event)
            var isAuthorized: Bool
            if #available(macOS 14.0, *) {
                isAuthorized = (status == .fullAccess)
            } else {
                isAuthorized = (status == .authorized)
            }

            if !isAuthorized && status == .notDetermined {
                if #available(macOS 14.0, *) {
                    isAuthorized = (try? await store.requestFullAccessToEvents()) ?? false
                } else {
                    isAuthorized = (try? await store.requestAccess(to: .event)) ?? false
                }
            }

            if isAuthorized {
                let cal = Calendar.current
                let now = Date()
                let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
                let endOfMonth = cal.date(byAdding: .day, value: 45, to: startOfMonth) ?? now

                let pred = store.predicateForEvents(withStart: startOfMonth, end: endOfMonth, calendars: nil)
                let ekEvents = store.events(matching: pred)

                var items: [CalendarItem] = []
                let df = DateFormatter()
                df.dateFormat = "EEE, HH:mm"

                for ev in ekEvents {
                    var r: Double? = nil
                    var g: Double? = nil
                    var b: Double? = nil
                    if let cgColor = ev.calendar.cgColor, let comps = cgColor.components, comps.count >= 3 {
                        r = Double(comps[0])
                        g = Double(comps[1])
                        b = Double(comps[2])
                    }

                    let timeStr: String
                    if ev.isAllDay {
                        timeStr = "All Day"
                    } else if let s = ev.startDate {
                        timeStr = df.string(from: s)
                    } else {
                        timeStr = ""
                    }

                    items.append(CalendarItem(
                        title: ev.title ?? "Event",
                        time: timeStr,
                        calendarName: ev.calendar.title,
                        startDate: ev.startDate,
                        endDate: ev.endDate,
                        colorR: r,
                        colorG: g,
                        colorB: b
                    ))
                }

                items.sort { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
                if !items.isEmpty {
                    return items
                }
            }

            // 2. Safe AppleScript fallback: ONLY execute if Calendar.app is ALREADY running.
            // Never launch or target Calendar if it is closed.
            let isCalRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.iCal").isEmpty
            guard isCalRunning else {
                return []
            }

            let script = """
            tell application "Calendar"
                set todayDate to current date
                set time of todayDate to 0
                set startOfMonth to todayDate - ((day of todayDate - 1) * days)
                set endOfMonth to startOfMonth + (45 * days)
                set eventList to {}
                repeat with c in calendars
                    try
                        set cName to (name of c)
                        set evs to (every event of c whose start date is greater than or equal to startOfMonth and start date is less than endOfMonth)
                        if (count of evs) > 0 then
                            set cClr to (color of c)
                            set rVal to (item 1 of cClr) / 65535
                            set gVal to (item 2 of cClr) / 65535
                            set bVal to (item 3 of cClr) / 65535
                            set colorStr to ((round (rVal * 255)) as integer as string) & "," & ((round (gVal * 255)) as integer as string) & "," & ((round (bVal * 255)) as integer as string)
                            repeat with ev in evs
                                set isoStart to (start date of ev as «class isot» as string)
                                try
                                    set isoEnd to (end date of ev as «class isot» as string)
                                on error
                                    set isoEnd to ""
                                end try
                                set end of eventList to (summary of ev) & "|||" & isoStart & "|||" & cName & "|||" & colorStr & "|||" & isoEnd
                            end repeat
                        end if
                    end try
                end repeat
                return eventList
            end tell
            """

            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                return []
            }

            let descriptor = appleScript.executeAndReturnError(&error)
            var items: [CalendarItem] = []

            let count = descriptor.numberOfItems
            if count > 0 {
                let localDateFormatter = DateFormatter()
                localDateFormatter.locale = Locale(identifier: "en_US_POSIX")
                localDateFormatter.timeZone = TimeZone.current
                localDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

                for i in 1...count {
                    if let itemStr = descriptor.atIndex(i)?.stringValue {
                        let parts = itemStr.components(separatedBy: "|||")
                        if parts.count >= 3 {
                            let title = parts[0]
                            let rawStartDate = parts[1]
                            let calName = parts[2]

                            var r: Double? = nil
                            var g: Double? = nil
                            var b: Double? = nil
                            if parts.count >= 4 {
                                let rgbParts = parts[3].components(separatedBy: ",")
                                if rgbParts.count >= 3,
                                   let rInt = Double(rgbParts[0].trimmingCharacters(in: .whitespaces)),
                                   let gInt = Double(rgbParts[1].trimmingCharacters(in: .whitespaces)),
                                   let bInt = Double(rgbParts[2].trimmingCharacters(in: .whitespaces)) {
                                    r = max(0.0, min(1.0, rInt / 255.0))
                                    g = max(0.0, min(1.0, gInt / 255.0))
                                    b = max(0.0, min(1.0, bInt / 255.0))
                                }
                            }

                            let parsedStartDate: Date? = localDateFormatter.date(from: rawStartDate)
                            var parsedEndDate: Date? = nil
                            if parts.count >= 5 && !parts[4].isEmpty {
                                parsedEndDate = localDateFormatter.date(from: parts[4])
                            }

                            let formatted = CalendarService.formatEventDate(rawStartDate, parsedDate: parsedStartDate)

                            items.append(CalendarItem(
                                title: title,
                                time: formatted,
                                calendarName: calName,
                                startDate: parsedStartDate,
                                endDate: parsedEndDate,
                                colorR: r,
                                colorG: g,
                                colorB: b
                            ))
                        }
                    }
                }
            }

            items.sort { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
            return items
        }.value
    }

    public nonisolated static func formatEventDate(_ raw: String, parsedDate: Date?) -> String {
        if let d = parsedDate {
            let calendar = Calendar.current
            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")
            timeFormatter.timeZone = TimeZone.current
            timeFormatter.dateFormat = "HH:mm"

            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayFormatter.timeZone = TimeZone.current
            dayFormatter.dateFormat = "EEE, d MMM"

            if calendar.isDateInToday(d) {
                return "Today, " + timeFormatter.string(from: d)
            } else if calendar.isDateInTomorrow(d) {
                return "Tomorrow, " + timeFormatter.string(from: d)
            } else if calendar.isDateInYesterday(d) {
                return "Yesterday, " + timeFormatter.string(from: d)
            } else {
                return dayFormatter.string(from: d) + " • " + timeFormatter.string(from: d)
            }
        }

        if raw.contains(" at ") {
            let parts = raw.components(separatedBy: " at ")
            let dayPart = parts[0].components(separatedBy: ",").first ?? parts[0]
            let timePart = parts[1].prefix(5)
            return "\(dayPart), \(timePart)"
        }
        return raw
    }

    public func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
