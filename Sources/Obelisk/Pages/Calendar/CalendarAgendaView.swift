import AppKit
import SwiftUI

/// Calendar page of the expanded notch.
/// Left: today's date and the day's agenda as a quiet time and title list.
/// Right: the current month as a compact grid. Today is a solid white disc, the current week sits on a
/// soft band, and days that hold events carry a thin underline. Uses the same system font as every other page.
@MainActor
public struct CalendarAgendaView: View {
    @ObservedObject var calendarService: CalendarService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared

    public init(calendarService: CalendarService? = nil) {
        self.calendarService = calendarService ?? .shared
    }

    private var calendar: Calendar { Calendar.current }

    /// Weeks of the current month. Cells outside the month are nil.
    private var monthWeeks: [[Date?]] {
        let cal = calendar
        guard let interval = cal.dateInterval(of: .month, for: Date()),
              let dayRange = cal.range(of: .day, in: .month, for: interval.start) else { return [] }

        let first = interval.start
        let weekdayOfFirst = cal.component(.weekday, from: first)
        let leading = (weekdayOfFirst - cal.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayRange.count {
            cells.append(cal.date(byAdding: .day, value: offset, to: first))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    private struct WeekdayHeader: Identifiable {
        let id: Int
        let symbol: String
        let isWeekend: Bool
    }

    private var weekdayHeaders: [WeekdayHeader] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        let reordered = Array(symbols[shift...] + symbols[..<shift])
        return reordered.enumerated().map { idx, sym in
            let weekday = ((shift + idx) % 7) + 1
            return WeekdayHeader(id: weekday, symbol: sym, isWeekend: (weekday == 1 || weekday == 7))
        }
    }

    private var contentHeight: CGFloat {
        max(90, 114 + CGFloat(settings.expandedHeightOffset))
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 0) {
            agendaColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: max(70, contentHeight - 18))
                .padding(.horizontal, 10)

            monthColumn
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: contentHeight)
        .padding(.top, 2)
        .brightness((settings.colorBrightness - 1.0) * 0.40)
        .onAppear {
            calendarService.fetchAgenda(force: true)
        }
    }

    // MARK: - Agenda Column

    private var agendaColumn: some View {
        let todayEvents = calendarService.events(on: Date(), includePassed: false)
        let maxEvents = settings.expandedHeightOffset > 30 ? 5 : (settings.expandedHeightOffset > 10 ? 4 : 3)
        let visible = Array(todayEvents.prefix(maxEvents))
        let isTodayRedDay = calendarService.isRedDay(on: Date())

        return VStack(alignment: .leading, spacing: 0) {
            Text(format("EEEE").uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(isTodayRedDay ? Color(red: 1.0, green: 0.32, blue: 0.35) : settings.resolvedColor(for: .calendarPrimary))

            Text(format("d MMMM"))
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                if visible.isEmpty {
                    Text("No upcoming events today")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    ForEach(visible) { event in
                        HStack(spacing: 10) {
                            Text(event.time)
                                .font(.system(size: 10.5, weight: .regular))
                                .monospacedDigit()
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                                .frame(width: 58, alignment: .leading)

                            Text(event.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    if todayEvents.count > visible.count {
                        Text("\(todayEvents.count - visible.count) more")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(.top, 9)
        }
    }

    // MARK: - Month Column

    private var monthColumn: some View {
        let weeks = monthWeeks
        let cellHeight: CGFloat = 13.5

        return VStack(spacing: 3) {
            Button(action: {
                calendarService.openCalendarApp()
            }) {
                HStack(spacing: 5) {
                    Text(format("MMMM yyyy"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()

            HStack(spacing: 0) {
                ForEach(weekdayHeaders) { header in
                    Text(header.symbol)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(header.isWeekend ? Color(red: 1.0, green: 0.32, blue: 0.35) : Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 11)

            VStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    weekRow(week, height: cellHeight)
                }
            }
        }
        .frame(maxWidth: 252)
    }

    private func weekRow(_ week: [Date?], height: CGFloat) -> some View {
        let containsToday = week.contains { date in
            guard let date else { return false }
            return calendar.isDateInToday(date)
        }

        return HStack(spacing: 0) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                dayCell(date, height: height)
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white.opacity(containsToday ? 0.07 : 0))
        )
    }

    @ViewBuilder
    private func dayCell(_ date: Date?, height: CGFloat) -> some View {
        if let date {
            let isToday = calendar.isDateInToday(date)
            let isRedDay = calendarService.isRedDay(on: date)
            let hasEvent = settings.showCalendarEventDots && calendarService.hasEvents(on: date)
            let dayNumber = calendar.component(.day, from: date)

            let defaultNumberColor: Color = isRedDay
                ? Color(red: 1.0, green: 0.32, blue: 0.35)
                : Color.white.opacity(0.85)

            let numberColor: Color = isToday
                ? (isRedDay ? Color(red: 0.88, green: 0.15, blue: 0.18) : Color.black)
                : defaultNumberColor

            let barColor: Color = isToday
                ? (isRedDay ? Color(red: 0.88, green: 0.15, blue: 0.18) : Color.black.opacity(0.85))
                : (calendarService.eventColor(on: date) ?? (isRedDay ? Color(red: 1.0, green: 0.32, blue: 0.35) : settings.resolvedColor(for: .calendarPrimary)))

            ZStack {
                if isToday {
                    Capsule(style: .continuous)
                        .fill(Color.white)
                        .frame(width: hasEvent ? (dayNumber >= 10 ? 25 : 21) : (dayNumber >= 10 ? 19 : 16), height: 15)
                }

                HStack(spacing: 2) {
                    if hasEvent {
                        Capsule()
                            .fill(barColor)
                            .frame(width: 1.5, height: 8)
                    }

                    Text(String(dayNumber))
                        .font(.system(size: 10, weight: isToday ? .bold : .regular))
                        .monospacedDigit()
                        .foregroundColor(numberColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
    }

    private func format(_ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: Date())
    }
}
