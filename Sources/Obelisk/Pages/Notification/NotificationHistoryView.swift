import AppKit
import Contacts
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

        return HStack(alignment: .top, spacing: 10) {
            // Apple-grade Avatar with App Icon Badge
            avatarWithAppBadgeView(item: item)
                .padding(.top, 1)

            // Notification Info
            VStack(alignment: .leading, spacing: 2.5) {
                // Line 1: Header (Sender Name on Left, Actions + Timestamp on Right)
                HStack(alignment: .center, spacing: 6) {
                    Text(primarySenderTitle(for: item))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    if isHovered {
                        HStack(spacing: 5) {
                            Button(action: {
                                notificationService.openNotificationApp(item)
                            }) {
                                Image(systemName: "arrow.up.forward.app.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .pointingHandCursor()

                            Button(action: {
                                notificationService.removeRecentNotification(id: item.id)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.65))
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .pointingHandCursor()
                        }
                        .transition(.opacity)
                    }

                    Text(item.formattedTimeAgo)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.48))
                        .lineLimit(1)
                }

                // Line 2: Group Name (in Bold, matching Apple's native layout)
                if let group = item.resolvedGroupName {
                    Text(group)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Line 3+: Message Body
                if !item.message.isEmpty {
                    Text(item.message)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.78))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.035))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .pointingHandCursor()
        .onTapGesture {
            notificationService.openNotificationApp(item)
        }
        .onHover { isInside in
            hoveredNotificationId = isInside ? item.id : nil
        }
    }

    private func primarySenderTitle(for item: ObeliskNotification) -> String {
        let sender = item.resolvedSenderName
        if !sender.isEmpty && sender != item.appName {
            return sender
        }
        if let group = item.resolvedGroupName {
            return group
        }
        return item.appName
    }

    // MARK: - Apple-grade Avatar with App Icon Badge

    @ViewBuilder
    private func avatarWithAppBadgeView(item: ObeliskNotification) -> some View {
        let isGroup = item.resolvedGroupName != nil
        let hasCustomSender = !item.resolvedSenderName.isEmpty && item.resolvedSenderName != item.appName
        let avatarSize: CGFloat = 36
        let badgeSize: CGFloat = 13.5

        ZStack(alignment: .bottomTrailing) {
            if let customAvatar = item.avatarImage ?? resolveContactImage(for: item.resolvedSenderName) {
                // Real Profile Photo (Clipped to Circle)
                Image(nsImage: customAvatar)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            } else if isGroup {
                // MARK: Profil Grup (Apple Group Avatar with person.2.fill)
                ZStack {
                    Circle()
                        .fill(groupAvatarGradient(for: item.resolvedGroupName ?? item.sender))

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.96))
                }
                .frame(width: avatarSize, height: avatarSize)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
            } else if hasCustomSender {
                // MARK: Profil Orang (Apple Person Avatar with person.fill)
                ZStack {
                    Circle()
                        .fill(personAvatarGradient(for: item.resolvedSenderName))

                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.96))
                }
                .frame(width: avatarSize, height: avatarSize)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
            } else {
                // MARK: Generic App Icon
                if let icon = item.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.12))
                        Image(systemName: "bell.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 26, height: 26)
                }
            }

            // Official App Badge (pinned to bottom-trailing corner)
            if (isGroup || hasCustomSender), let icon = item.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: badgeSize, height: badgeSize)
                    .clipShape(RoundedRectangle(cornerRadius: 3.2, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.2, style: .continuous)
                            .stroke(Color(red: 22/255, green: 22/255, blue: 24/255), lineWidth: 1.5)
                    )
                    .offset(x: 2.5, y: 2.5)
            }
        }
        .frame(width: avatarSize + 3, height: avatarSize + 3)
    }

    private func resolveContactImage(for name: String) -> NSImage? {
        guard !name.isEmpty else { return nil }
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            let store = CNContactStore()
            let predicate = CNContact.predicateForContacts(matchingName: name)
            if let list = try? store.unifiedContacts(matching: predicate, keysToFetch: [CNContactThumbnailImageDataKey as CNKeyDescriptor]),
               let first = list.first(where: { $0.thumbnailImageData != nil }),
               let data = first.thumbnailImageData {
                return NSImage(data: data)
            }
        }
        return nil
    }

    private func groupAvatarGradient(for name: String) -> LinearGradient {
        let hash = abs(name.hashValue)
        let palettes: [[Color]] = [
            [Color(red: 40/255, green: 115/255, blue: 85/255), Color(red: 25/255, green: 80/255, blue: 60/255)],  // WhatsApp Forest Green
            [Color(red: 45/255, green: 110/255, blue: 120/255), Color(red: 30/255, green: 80/255, blue: 90/255)],  // Emerald Teal
            [Color(red: 60/255, green: 100/255, blue: 130/255), Color(red: 40/255, green: 75/255, blue: 105/255)], // Deep Pine
            [Color(red: 50/255, green: 120/255, blue: 110/255), Color(red: 30/255, green: 85/255, blue: 80/255)]   // Sage Seafoam
        ]
        let colors = palettes[hash % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func personAvatarGradient(for name: String) -> LinearGradient {
        let hash = abs(name.hashValue)
        let palettes: [[Color]] = [
            [Color(red: 60/255, green: 115/255, blue: 165/255), Color(red: 40/255, green: 85/255, blue: 135/255)], // Classic Apple Blue
            [Color(red: 135/255, green: 80/255, blue: 135/255), Color(red: 95/255, green: 55/255, blue: 100/255)],  // Orchid Violet
            [Color(red: 165/255, green: 95/255, blue: 65/255), Color(red: 125/255, green: 65/255, blue: 40/255)],  // Warm Ochre
            [Color(red: 85/255, green: 95/255, blue: 135/255), Color(red: 55/255, green: 65/255, blue: 105/255)],  // Slate Indigo
            [Color(red: 155/255, green: 75/255, blue: 85/255), Color(red: 115/255, green: 50/255, blue: 60/255)]   // Muted Rose
        ]
        let colors = palettes[hash % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
