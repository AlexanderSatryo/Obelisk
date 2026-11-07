import AppKit
import SwiftUI

/// Dedicated dashboard page inside the expanded Obelisk notch for browsing and managing recent notifications.
public struct NotificationHistoryView: View {
    @ObservedObject var notificationService: NotificationService = .shared
    @ObservedObject var biometrics: BiometricPrivacyService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared
    @ObservedObject var windowManager: WindowManager = .shared

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
        .onAppear {
            autoAuthenticateWithTouchID()
        }
        .onChange(of: windowManager.isExpanded) { isExpanded in
            if isExpanded && windowManager.currentTab == .notification {
                autoAuthenticateWithTouchID()
            }
        }
        .onChange(of: windowManager.currentTab) { tab in
            if tab == .notification && windowManager.isExpanded {
                autoAuthenticateWithTouchID()
            }
        }
    }

    private func autoAuthenticateWithTouchID() {
        guard settings.requireTouchIDForNotifications, !biometrics.isUnlocked else { return }
        // Automatically request Touch ID immediately upon opening the page
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard self.windowManager.isExpanded, self.windowManager.currentTab == .notification else { return }
            self.biometrics.authenticate(reason: "Touch ID to view recent notifications")
        }
    }

    // MARK: - Locked Privacy State

    private var lockedPrivacyView: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "touchid")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(Color(red: 52/255, green: 199/255, blue: 89/255))
            }

            VStack(spacing: 2) {
                Text("Touch ID Required")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)

                Text("Touch the sensor on your Mac keyboard to unlock notifications.")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
            }

            if let error = biometrics.lastErrorMessage {
                Text(error)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .pointingHandCursor()
        .onTapGesture {
            autoAuthenticateWithTouchID()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 7) {
            Image(systemName: "bell.slash")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.35))

            VStack(spacing: 2) {
                Text("No Recent Notifications")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Text("Notifications from WhatsApp, Mail, and other applications will appear here.")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recent Notifications Feed

    private var recentFeedView: some View {
        VStack(spacing: 5) {
            // Header Bar with Quick Actions
            HStack(spacing: 6) {
                Text("Recent")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

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
                    if !item.sender.isEmpty {
                        Text(item.sender + ":")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }

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
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(isHovered ? .white : .white.opacity(0.55))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
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
