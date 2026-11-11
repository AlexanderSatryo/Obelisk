import AppKit
import SwiftUI

/// Apple-grade biometric Touch ID glyph indicator with authentic scanning,
/// filling, ripple, and morphing unlock animations for the Obelisk notch.
public struct AppleTouchIDGlyphView: View {
    public let isAuthenticating: Bool
    public let isUnlocked: Bool
    public let hasError: Bool
    public var size: CGFloat = 40

    @State private var scanSweep: CGFloat = 0.20
    @State private var breathingScale: CGFloat = 1.0
    @State private var breathingGlow: Double = 0.12
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.0
    @State private var shakeOffset: CGFloat = 0.0

    public init(
        isAuthenticating: Bool,
        isUnlocked: Bool,
        hasError: Bool,
        size: CGFloat = 40
    ) {
        self.isAuthenticating = isAuthenticating
        self.isUnlocked = isUnlocked
        self.hasError = hasError
        self.size = size
    }

    private var activeColor: Color {
        if hasError {
            return Color(red: 255/255, green: 69/255, blue: 58/255) // Apple Red
        } else if isUnlocked {
            return Color(red: 50/255, green: 215/255, blue: 75/255) // Bright Apple Emerald
        } else {
            return Color(red: 52/255, green: 199/255, blue: 89/255) // Classic Apple Green
        }
    }

    public var body: some View {
        ZStack {
            // Sonar ripple wave ring radiating outward on success
            Circle()
                .stroke(activeColor.opacity(rippleOpacity), lineWidth: 1.8)
                .frame(width: size, height: size)
                .scaleEffect(rippleScale)

            // Background ambient glow circle
            Circle()
                .fill(activeColor.opacity(breathingGlow))
                .frame(width: size, height: size)
                .scaleEffect(breathingScale)
                .overlay(
                    Circle()
                        .stroke(activeColor.opacity(isUnlocked ? 0.60 : 0.22), lineWidth: 1.0)
                )

            // Hollow outline layer (empty fingerprint baseline)
            Image(systemName: "touchid")
                .font(.system(size: size * 0.50, weight: .regular))
                .foregroundColor(Color.white.opacity(0.18))
                .opacity(isUnlocked ? 0.0 : 1.0)

            // Progressively filling scan layer (animates from bottom to top)
            if !isUnlocked {
                Image(systemName: "touchid")
                    .font(.system(size: size * 0.50, weight: .medium))
                    .foregroundColor(activeColor)
                    .mask(
                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .frame(height: geo.size.height * max(0.10, min(1.0, scanSweep)))
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                        }
                    )
            }

            // Unlocked morphing layer: pad lock open with gentle spring pop
            if isUnlocked {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundColor(activeColor)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.60).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(width: size, height: size)
        .offset(x: shakeOffset)
        .onAppear {
            startBreathingScanAnimation()
        }
        .onChange(of: isAuthenticating) { authenticating in
            if authenticating {
                startBreathingScanAnimation()
            }
        }
        .onChange(of: isUnlocked) { unlocked in
            if unlocked {
                triggerUnlockAnimation()
            }
        }
        .onChange(of: hasError) { error in
            if error {
                triggerShakeAnimation()
            }
        }
    }

    private func startBreathingScanAnimation() {
        guard !isUnlocked else { return }
        // Biometric breathing pulse
        withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
            breathingScale = 1.10
            breathingGlow = 0.24
            scanSweep = 0.95
        }
    }

    private func triggerUnlockAnimation() {
        // Stop breathing
        breathingScale = 1.0
        breathingGlow = 0.30
        scanSweep = 1.0

        // Sonar ripple expansion
        rippleScale = 1.0
        rippleOpacity = 0.85
        withAnimation(.easeOut(duration: 0.42)) {
            rippleScale = 1.70
            rippleOpacity = 0.0
        }

        // Haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    private func triggerShakeAnimation() {
        let sequence: [(offset: CGFloat, delay: Double)] = [
            (-6, 0.00),
            (6, 0.06),
            (-4, 0.12),
            (4, 0.18),
            (0, 0.24)
        ]
        for step in sequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                withAnimation(.linear(duration: 0.06)) {
                    self.shakeOffset = step.offset
                }
            }
        }
    }
}

