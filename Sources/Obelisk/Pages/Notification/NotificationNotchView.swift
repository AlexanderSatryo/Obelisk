import SwiftUI

/// Renders the Dynamic Island notification layout inside the Obelisk compact notch.
/// Displays symmetrical wings `[App Icon + App Name] ... [Camera Notch] ... [New Notifications!]`
/// Clicking the wings dismisses the notification HUD cleanly without accidentally expanding the dashboard.
public struct NotificationNotchView: View {
    let notification: ObeliskNotification
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var notificationService: NotificationService = .shared
    @ObservedObject var settings: ObeliskSettings = .shared

    public var body: some View {
        let totalWidth = windowManager.compactWidth
        let topRowHeight = max(24, ScreenGeometry.notchSize.height + CGFloat(settings.compactHeightOffset))
        let bezelWidth = ScreenGeometry.notchSize.width
        let wingWidth = max(0, (totalWidth - bezelWidth) / 2.0)
        let earR = windowManager.activeCompactTopEarRadius
        let visibleBodyWidth = max(0, wingWidth - earR)

        HStack(spacing: 0) {
            if visibleBodyWidth >= 16 {
                Color.clear.frame(width: earR, height: topRowHeight)

                // Left Wing: [App Logo - App Name]
                HStack(spacing: 6) {
                    appIconView(size: 16)

                    Text(notification.appName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(width: visibleBodyWidth, height: topRowHeight, alignment: .center)

                Color.clear.frame(width: bezelWidth, height: topRowHeight)

                // Right Wing: [New Notifications!]
                HStack(spacing: 0) {
                    Text("New Notifications!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(width: visibleBodyWidth, height: topRowHeight, alignment: .center)

                Color.clear.frame(width: earR, height: topRowHeight)
            }
        }
        .frame(width: totalWidth, height: topRowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss standby notification HUD cleanly
            notificationService.dismissNotification()
        }
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
