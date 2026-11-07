import AppKit
import SwiftUI

/// Dedicated dashboard page inside the expanded Obelisk notch for browsing and managing recent notifications.
public struct NotificationHistoryView: View {
    @ObservedObject var notificationService: NotificationService = .shared
    @ObservedObject var biometrics: BiometricPrivacyService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared

    @State private var hoveredNotificationId: UUID? = nil

    public init() {}

    private var isLocked: Bool {
        settings.requireTouchIDForNotifications && !biometrics.isUnlocked
    }

    public var body: some View {
        VStack(spacing: 6) {
            if isLocked {
                lockedPrivacyView
            } else if notificationService.recentNotifications.isEmpty {
                emptyStateView
            } else {
                recentFeedView
            }
        }
        .frame(height: 114)
        .padding(.top, 2)
    }

    // MARK: - Locked Privacy State

    private var lockedPrivacyView: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 34)
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            VStack(spacing: 2) {
                Text("Notifications Protected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text("Touch ID is required to reveal message contents and senders.")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
            }

            Button(action: {
                biometrics.authenticate(reason: "Touch ID to view recent notifications")
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "touchid")
                        .font(.system(size: 11, weight: .bold))
                    Text("Unlock with Touch ID")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "bell.slash")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.white.opacity(0.40))

            VStack(spacing: 2) {
                Text("No Recent Notifications")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Text("Incoming alerts from WhatsApp, Mail, and other apps will appear here.")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 8) {
                Button(action: {
                    notificationService.simulateSample(type: .whatsapp)
                }) {
                    Text("+ WhatsApp Alert")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .pointingHandCursor()

                Button(action: {
                    notificationService.simulateSample(type: .mail)
                }) {
                    Text("+ Mail Alert")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recent Notifications Feed

    private var recentFeedView: some View {
        VStack(spacing: 5) {
            // Header Bar with Count & Quick Actions
            HStack(spacing: 6) {
                Text("Recent")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Text("\(notificationService.recentNotifications.count)")
                    .font(.system(size: 9.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                if settings.requireTouchIDForNotifications {
                    Button(action: {
                        biometrics.lock()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8.5, weight: .semibold))
                            Text("Lock")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }

                Button(action: {
                    notificationService.clearAllRecentNotifications()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                            .font(.system(size: 8.5, weight: .semibold))
                        Text("Clear All")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            .padding(.horizontal, 2)

            // Scrollable Recent Notifications List
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 4) {
                    ForEach(notificationService.recentNotifications) { item in
                        notificationRow(item)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    // MARK: - Notification Item Row

    private func notificationRow(_ item: ObeliskNotification) -> some View {
        let isHovered = hoveredNotificationId == item.id

        return HStack(spacing: 8) {
            // App Icon
            if let icon = item.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
            } else {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12))
                    Image(systemName: "bell.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 20, height: 20)
            }

            // Notification Info
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 4) {
                    Text(item.appName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Text("•")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))

                    Text(item.formattedTimeAgo)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))

                    Spacer()
                }

                HStack(spacing: 4) {
                    Text(item.sender + ":")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)

                    Text(item.message)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(1)

                    Spacer(minLength: 4)
                }
            }

            // Quick Actions
            HStack(spacing: 6) {
                Button(action: {
                    notificationService.openNotificationApp(item)
                }) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isHovered ? .white : .white.opacity(0.6))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(isHovered ? 0.15 : 0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()

                Button(action: {
                    notificationService.removeRecentNotification(id: item.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.03))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isInside in
            hoveredNotificationId = isInside ? item.id : nil
        }
    }
}
