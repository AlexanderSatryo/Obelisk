import SwiftUI

/// Renders the Dynamic Island notification layout inside the Obelisk notch.
/// Displays symmetrical wings `[App Icon + App Name] ... [Camera Notch] ... [New Notifications! 🔒]`
/// and expands into an Apple-grade notification card upon Touch ID authentication.
public struct NotificationNotchView: View {
    let notification: ObeliskNotification
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var notificationService: NotificationService = .shared
    @ObservedObject var biometrics: BiometricPrivacyService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared

    public static let cardBodyHeight: CGFloat = 114

    private var isUnlocked: Bool {
        biometrics.isUnlocked
    }

    private var isExpanded: Bool {
        notificationService.isCardExpanded
    }

    public var body: some View {
        if isExpanded {
            expandedCardView
        } else {
            collapsedWingsView
        }
    }

    // MARK: - Collapsed Notification Wings View

    private var collapsedWingsView: some View {
        let totalWidth = windowManager.compactWidth
        let topRowHeight = max(24, ScreenGeometry.notchSize.height + CGFloat(settings.compactHeightOffset))
        let notchWidth = ScreenGeometry.notchSize.width
        let wingWidth = max(0, (totalWidth - notchWidth) / 2.0)

        return HStack(spacing: 0) {
            if wingWidth >= 16 {
                // Left Wing: [App Logo - App Name]
                HStack(spacing: 6) {
                    appIconView(size: 16)

                    Text(notification.appName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .offset(x: 5.5)
                .frame(width: wingWidth, alignment: .center)

                Spacer(minLength: notchWidth)

                // Right Wing: [New Notifications! 🔒]
                HStack(spacing: 5) {
                    Text("New Notifications!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isUnlocked ? Color(red: 52/255, green: 199/255, blue: 89/255) : .white.opacity(0.85))
                        .scaleEffect(isUnlocked ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isUnlocked)
                }
                .offset(x: -5.5)
                .frame(width: wingWidth, alignment: .center)
            }
        }
        .frame(width: totalWidth, height: topRowHeight)
    }

    // MARK: - Unlocked Extended Notification Card

    private var expandedCardView: some View {
        let totalWidth = windowManager.compactWidth
        let topRowHeight = max(24, ScreenGeometry.notchSize.height + CGFloat(settings.compactHeightOffset))

        return VStack(spacing: 0) {
            // Camera bezel clearance band
            Color.clear.frame(height: topRowHeight)

            VStack(alignment: .leading, spacing: 8) {
                // Header row: App Icon, App Name, Timestamp, Unlocked indicator
                HStack(spacing: 8) {
                    appIconView(size: 20)

                    Text(notification.appName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)

                    Text("•")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))

                    Text("Just now")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(Color(red: 52/255, green: 199/255, blue: 89/255))

                        Text("Unlocked")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.12))
                    .clipShape(Capsule())
                }

                // Sender and Message text
                VStack(alignment: .leading, spacing: 2.5) {
                    Text(notification.sender)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(notification.message)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Action buttons: [Open App] and [Dismiss]
                HStack(spacing: 10) {
                    Button(action: {
                        notificationService.openApp()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Open \(notification.appName)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()

                    Button(action: {
                        notificationService.dismissNotification()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Dismiss")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()

                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 10)
            .frame(height: Self.cardBodyHeight, alignment: .top)
        }
        .frame(width: totalWidth)
    }

    // MARK: - App Icon Rendering

    @ViewBuilder
    private func appIconView(size: CGFloat) -> some View {
        if let icon = notification.appIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                Image(systemName: "bell.fill")
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }
}

