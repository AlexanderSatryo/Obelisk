import AppKit
import Foundation
@preconcurrency import LocalAuthentication
import SwiftUI

/// Manages native Apple Touch ID / biometrics authentication to protect private notification contents.
@MainActor
public final class BiometricPrivacyService: ObservableObject {
    public static let shared = BiometricPrivacyService()

    @Published public var isUnlocked: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var canUseBiometrics: Bool = false
    @Published public var biometryType: LABiometryType = .none
    @Published public var lastErrorMessage: String? = nil
    @Published public var lastAuthenticationFinishTime: Date = .distantPast

    private var activeContext: LAContext? = nil
    private var lastInvalidationTime: Date = .distantPast
    private var focusWatchdogTimer: Timer? = nil
    private var pendingAuthWorkItem: DispatchWorkItem? = nil

    private init() {
        checkBiometrics()
    }

    /// Checks hardware biometrics capability on this Mac.
    public func checkBiometrics() {
        let context = LAContext()
        var error: NSError?
        self.canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        self.biometryType = context.biometryType
    }

    /// Human-readable biometrics label (e.g. "Touch ID" or "Face ID").
    public var biometryLabel: String {
        switch biometryType {
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        default:
            return "Touch ID"
        }
    }

    /// Evaluates biometrics (or device passcode if biometrics are unavailable) to unlock the notification card.
    public func authenticate(
        reason: String = "Touch ID to view recent notifications",
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !isUnlocked else {
            completion?(true)
            return
        }

        // If an authentication session is already active, ensure the system Touch ID UIAgent has focus
        if isAuthenticating, activeContext != nil {
            ensureTouchIDAgentFocused()
            return
        }

        pendingAuthWorkItem?.cancel()
        pendingAuthWorkItem = nil

        // If a previous LAContext was just invalidated (< 0.25s ago), wait briefly for AppleMesaSEPDriver
        // and coreauthd (_bkIsBusy) to finish releasing the hardware Touch ID sensor before starting a new session.
        let sinceInvalidation = Date().timeIntervalSince(lastInvalidationTime)
        let cooldownDelay = max(0.0, 0.26 - sinceInvalidation)

        if cooldownDelay > 0.01 {
            let work = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.startEvaluation(reason: reason, completion: completion)
                }
            }
            pendingAuthWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + cooldownDelay, execute: work)
        } else {
            startEvaluation(reason: reason, completion: completion)
        }
    }

    private func startEvaluation(
        reason: String,
        completion: ((Bool) -> Void)?
    ) {
        guard !isUnlocked, !isAuthenticating else { return }
        guard WindowManager.shared.isExpanded, WindowManager.shared.currentTab == .notification else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        self.activeContext = context

        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        isAuthenticating = true
        lastErrorMessage = nil
        startFocusWatchdog()

        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, authError in
            Task { @MainActor in
                guard let self = self else { return }
                // Ignore stale completion callbacks from previously invalidated contexts
                guard self.activeContext === context else { return }

                self.activeContext = nil
                self.isAuthenticating = false
                self.stopFocusWatchdog()
                self.lastAuthenticationFinishTime = Date()

                if success {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        self.isUnlocked = true
                    }
                    completion?(true)
                } else {
                    if let err = authError as? LAError {
                        if err.code != .userCancel && err.code != .appCancel && err.code != .systemCancel {
                            self.lastErrorMessage = err.localizedDescription
                        }
                    }
                    completion?(false)
                }
            }
        }
    }

    /// Keeps `com.apple.LocalAuthentication.UIAgent` (`CoreAuthUI`) focused while the Touch ID prompt is visible.
    /// Prevents background or Electron apps from stealing focus (`UI event 5 LostFocus`, LAError -4) which otherwise
    /// pauses the hardware Touch ID sensor while leaving the dialog on screen.
    private func startFocusWatchdog() {
        stopFocusWatchdog()

        for delay in [0.08, 0.18, 0.32, 0.50, 0.75] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.isAuthenticating else { return }
                self.ensureTouchIDAgentFocused()
            }
        }

        let timer = Timer(timeInterval: 0.22, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isAuthenticating else { return }
                self.ensureTouchIDAgentFocused()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.focusWatchdogTimer = timer
    }

    private func stopFocusWatchdog() {
        focusWatchdogTimer?.invalidate()
        focusWatchdogTimer = nil
    }

    private func ensureTouchIDAgentFocused() {
        guard isAuthenticating, WindowManager.shared.isExpanded else { return }
        let agents = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.LocalAuthentication.UIAgent")
        if let agent = agents.first, !agent.isActive {
            agent.activate(options: [.activateIgnoringOtherApps])
        }
    }

    /// Locks notification privacy and clears authentication state.
    public func lock() {
        pendingAuthWorkItem?.cancel()
        pendingAuthWorkItem = nil
        stopFocusWatchdog()

        if let ctx = activeContext {
            activeContext = nil
            lastInvalidationTime = Date()
            ctx.invalidate()
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            self.isUnlocked = false
            self.isAuthenticating = false
            self.lastErrorMessage = nil
        }
    }
}
