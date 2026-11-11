import AppKit
import SwiftUI

/// Dedicated dashboard page for configuring and previewing scheduled reminders and routines.
/// Sits as a first-class page in the expanded notch, positioned immediately before Notifications.
public struct ScheduledAlertsPageView: View {
    @ObservedObject var alertService: ScheduledAlertService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared

    @State private var newTitle: String = ""
    @State private var hourText: String = "08"
    @State private var minuteText: String = "30"
    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 30
    @State private var selectedRecurrence: AlertRecurrence = .weekdays
    @State private var hoveredAlertId: UUID? = nil

    private let amberColor = Color(red: 255/255, green: 159/255, blue: 10/255)
    private let calmGreen = Color(red: 52/255, green: 199/255, blue: 89/255)

    public init() {}

    private var contentHeight: CGFloat {
        max(90, 114 + CGFloat(settings.expandedHeightOffset))
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left Column: Active Scheduled Alerts List
            alertsListColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            // Symmetrical divider matching Calendar and Media pages
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: max(70, contentHeight - 18))
                .padding(.horizontal, 10)

            // Right Column: Apple-native Routine Composer Form
            createAlertColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: contentHeight)
        .padding(.top, 2)
        .brightness((settings.colorBrightness - 1.0) * 0.40)
    }

    // MARK: - Left Column: Alerts List

    private var alertsListColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(amberColor)

                Text("SCHEDULED ALERTS")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(amberColor)

                Spacer()

                let activeCount = alertService.alerts.filter { $0.isEnabled }.count
                Text("\(activeCount) active")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.trailing, 4)

            if alertService.alerts.isEmpty {
                VStack(alignment: .center, spacing: 5) {
                    Spacer()
                    Image(systemName: "bell.slash")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.28))
                    Text("No scheduled alerts yet")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Add a routine using the form on the right.")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.32))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(alertService.alerts) { alert in
                            alertRow(alert)
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
        }
    }

    private func alertRow(_ alert: ScheduledAlertItem) -> some View {
        let isHovered = hoveredAlertId == alert.id

        return HStack(spacing: 8) {
            // Digital Time Display (Apple Clock style)
            Text(alert.time)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(alert.isEnabled ? .white : .white.opacity(0.35))
                .frame(width: 44, alignment: .leading)

            // Title & Recurrence Tag
            VStack(alignment: .leading, spacing: 1.5) {
                Text(alert.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(alert.isEnabled ? .white : .white.opacity(0.40))
                    .lineLimit(1)

                Text(alert.recurrence.shortLabel)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(alert.isEnabled ? amberColor.opacity(0.9) : .white.opacity(0.30))
            }

            Spacer(minLength: 4)

            // Quick Actions on Hover
            if isHovered {
                HStack(spacing: 5) {
                    // Test Trigger on Notch
                    Button(action: {
                        alertService.testTriggerAlert(alert)
                    }) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(amberColor)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(amberColor.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .help("Preview alert on notch")

                    // Delete Alert
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            alertService.deleteAlert(id: alert.id)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 9.5))
                            .foregroundColor(Color.red.opacity(0.85))
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.red.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Delete alert")
                }
                .transition(.opacity)
            }

            // Apple Native Toggle Switch
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    alertService.toggleAlert(id: alert.id)
                }
            }) {
                ZStack(alignment: alert.isEnabled ? .trailing : .leading) {
                    Capsule()
                        .fill(alert.isEnabled ? calmGreen : Color.white.opacity(0.18))
                        .frame(width: 26, height: 15)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .padding(1.5)
                        .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
                }
            }
            .buttonStyle(.plain)
            .help(alert.isEnabled ? "Disable alert" : "Enable alert")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(isHovered ? 0.12 : 0.04), lineWidth: 0.5)
        )
        .onHover { h in
            hoveredAlertId = h ? alert.id : nil
        }
    }

    // MARK: - Right Column: Apple-Grade Form & Composer

    private var createAlertColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))

                Text("NEW ALERT")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.white.opacity(0.85))

                Spacer()
            }

            // Apple Reminders Grouped Card Container
            VStack(spacing: 0) {
                // Row 1: Title Input Field
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(amberColor.opacity(0.85))

                    TextField("Title (e.g. Fill Attendance)", text: $newTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white)

                    if !newTitle.isEmpty {
                        Button(action: { newTitle = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.40))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)

                // Hairline Separator
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)

                // Row 2: Tactile Time Stepper ([ - ] 08 [ + ] : [ - ] 30 [ + ]) & Recurrence Dropdown
                HStack(spacing: 8) {
                    // Tactile Time Controls (Typeable + Circular Steppers)
                    digitalTimeStepper

                    Spacer(minLength: 4)

                    // Single Recurrence Dropdown Menu
                    recurrenceDropdownMenu
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
            )

            // Primary Add Alert Button
            Button(action: saveAlert) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9.5, weight: .bold))
                    Text("Add Alert")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .foregroundColor(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.35) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.10) : amberColor)
                )
            }
            .buttonStyle(.plain)
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.top, 2)
        }
        .padding(.leading, 2)
    }

    // MARK: - Digital Time Stepper (Tactile Steppers + Typeable Display)

    private var digitalTimeStepper: some View {
        HStack(spacing: 4) {
            // Hour Capsule: [ - ] 08 [ + ]
            HStack(spacing: 3) {
                Button(action: { decrementHour() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 15, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                TextField("08", text: $hourText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 20)
                    .onChange(of: hourText) { newValue in
                        let digits = newValue.filter { $0.isNumber }
                        let truncated = String(digits.prefix(2))
                        if truncated != newValue {
                            hourText = truncated
                        }
                        if let h = Int(truncated) {
                            selectedHour = min(23, max(0, h))
                        }
                    }

                Button(action: { incrementHour() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 15, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 0.5))

            Text(":")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.40))

            // Minute Capsule: [ - ] 30 [ + ]
            HStack(spacing: 3) {
                Button(action: { decrementMinute() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 15, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                TextField("30", text: $minuteText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 20)
                    .onChange(of: minuteText) { newValue in
                        let digits = newValue.filter { $0.isNumber }
                        let truncated = String(digits.prefix(2))
                        if truncated != newValue {
                            minuteText = truncated
                        }
                        if let m = Int(truncated) {
                            selectedMinute = min(59, max(0, m))
                        }
                    }

                Button(action: { incrementMinute() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 15, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
        }
    }

    // MARK: - Recurrence Dropdown Menu

    private var recurrenceDropdownMenu: some View {
        Menu {
            ForEach(AlertRecurrence.allCases) { rec in
                Button(action: {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedRecurrence = rec
                    }
                }) {
                    HStack {
                        Text(rec.rawValue)
                        if selectedRecurrence == rec {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedRecurrence.shortLabel)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .pointingHandCursor()
    }

    // MARK: - Actions

    private func incrementHour() {
        withAnimation(.easeOut(duration: 0.12)) {
            selectedHour = (selectedHour + 1) % 24
            hourText = String(format: "%02d", selectedHour)
        }
    }

    private func decrementHour() {
        withAnimation(.easeOut(duration: 0.12)) {
            selectedHour = (selectedHour - 1 + 24) % 24
            hourText = String(format: "%02d", selectedHour)
        }
    }

    private func incrementMinute() {
        withAnimation(.easeOut(duration: 0.12)) {
            selectedMinute = (selectedMinute + 5) % 60
            minuteText = String(format: "%02d", selectedMinute)
        }
    }

    private func decrementMinute() {
        withAnimation(.easeOut(duration: 0.12)) {
            selectedMinute = (selectedMinute - 5 + 60) % 60
            minuteText = String(format: "%02d", selectedMinute)
        }
    }

    private func saveAlert() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let h = Int(hourText) ?? selectedHour
        let m = Int(minuteText) ?? selectedMinute
        let validH = min(23, max(0, h))
        let validM = min(59, max(0, m))

        let timeString = String(format: "%02d:%02d", validH, validM)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            alertService.addAlert(
                title: title,
                time: timeString,
                recurrence: selectedRecurrence
            )
            newTitle = ""
            hourText = String(format: "%02d", validH)
            minuteText = String(format: "%02d", validM)
        }
    }
}
