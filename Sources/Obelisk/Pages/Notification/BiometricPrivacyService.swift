import Foundation
import LocalAuthentication
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
        reason: String = "Touch ID to view private notification",
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !isUnlocked else {
            completion?(true)
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        isAuthenticating = true
        lastErrorMessage = nil

        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, authError in
            Task { @MainActor in
                guard let self = self else { return }
                self.isAuthenticating = false
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

    /// Locks notification privacy and clears authentication state.
    public func lock() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            self.isUnlocked = false
            self.isAuthenticating = false
            self.lastErrorMessage = nil
        }
    }
}

