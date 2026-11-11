import AppKit
import SwiftUI

/// Apple-grade biometric Touch ID glyph indicator for the Obelisk notch.
/// - Waiting state: Completely still ("diam"), neutral translucent glyph with no distracting pulse loops.
/// - Unlocked state: The fingerprint itself instantly turns full vibrant Apple green with a spring pop,
///   glowing backdrop, and expanding sonar ripple ring (replacing the padlock icon).
public struct AppleTouchIDGlyphView: View {
    public let isAuthenticating: Bool
    public let isUnlocked: Bool
    public let hasError: Bool
    public var size: CGFloat = 40

    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.0
    @State private var shakeOffset: CGFloat = 0.0
    @State private var glyphScale: CGFloat = 1.0

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
            return Color(red: 50/255, green: 215/255, blue: 75/255) // Vibrant Apple Emerald
        } else {
            return Color.white.opacity(0.45) // Calm, still neutral outline while waiting
        }
    }

    private var circleFillColor: Color {
        if hasError {
            return Color(red: 255/255, green: 69/255, blue: 58/255).opacity(0.18)
        } else if isUnlocked {
            return Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.22)
        } else {
            return Color.white.opacity(0.08)
        }
    }

    private var circleStrokeColor: Color {
        if hasError {
            return Color(red: 255/255, green: 69/255, blue: 58/255).opacity(0.40)
        } else if isUnlocked {
            return Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.70)
        } else {
            return Color.white.opacity(0.14)
        }
    }

    public var body: some View {
        ZStack {
            // Sonar ripple wave ring radiating outward on successful Touch ID recognition
            Circle()
                .stroke(Color(red: 50/255, green: 215/255, blue: 75/255).opacity(rippleOpacity), lineWidth: 1.8)
                .frame(width: size, height: size)
                .scaleEffect(rippleScale)

            // Background badge circle (subtle neutral when waiting, vibrant green glow when unlocked)
            Circle()
                .fill(circleFillColor)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(circleStrokeColor, lineWidth: isUnlocked ? 1.5 : 1.0)
                )

            // Single Touch ID Fingerprint Glyph:
            // - Still / neutral when waiting
            // - Instant full vibrant green with spring pop upon unlock
            Image(systemName: "touchid")
                .font(.system(size: size * 0.52, weight: isUnlocked ? .semibold : .medium))
                .foregroundColor(activeColor)
                .scaleEffect(glyphScale)
        }
        .frame(width: size, height: size)
        .offset(x: shakeOffset)
        .onChange(of: isUnlocked) { unlocked in
            if unlocked {
                triggerUnlockAnimation()
            } else {
                glyphScale = 1.0
                rippleOpacity = 0.0
            }
        }
        .onChange(of: hasError) { error in
            if error {
                triggerShakeAnimation()
            }
        }
    }

    private func triggerUnlockAnimation() {
        // Pop the fingerprint glyph slightly for a crisp tactile feel
        withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
            glyphScale = 1.12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.80)) {
                self.glyphScale = 1.0
            }
        }

        // Sonar ripple expansion
        rippleScale = 1.0
        rippleOpacity = 0.85
        withAnimation(.easeOut(duration: 0.40)) {
            rippleScale = 1.75
            rippleOpacity = 0.0
        }

        // Native Mac haptic feedback
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
