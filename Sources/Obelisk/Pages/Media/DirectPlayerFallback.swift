import Foundation
import AppKit

/// Reads Spotify and Apple Music directly through their AppleScript dictionaries.
/// Used when the MediaRemote sidecar cannot run (for example on Macs without Xcode / Command Line Tools),
/// so track metadata, playback position and synchronized lyrics still work on any Mac.
@MainActor
public final class DirectPlayerFallback {
    public static let shared = DirectPlayerFallback()

    private var timer: Timer?
    private var isPolling = false

    private struct PlayerSpec {
        let bundleId: String
        let appName: String
        /// Spotify reports the duration in milliseconds, Music in seconds.
        let durationDivisor: Double
    }

    private let specs = [
        PlayerSpec(bundleId: "com.spotify.client", appName: "Spotify", durationDivisor: 1000),
        PlayerSpec(bundleId: "com.apple.Music", appName: "Music", durationDivisor: 1)
    ]

    private init() {}

    public func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        // The sidecar is the preferred source; only fall back when it is not delivering data.
        guard !MediaRemoteBridge.shared.isHealthy, !isPolling else { return }

        let running = specs.filter { spec in
            NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == spec.bundleId && !$0.isTerminated
            }
        }
        guard !running.isEmpty else { return }

        isPolling = true
        let specsToPoll = running
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var states: [RemoteMediaState] = []
            for spec in specsToPoll {
                if let state = DirectPlayerFallback.query(spec) {
                    states.append(state)
                }
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self = self else { return }
                    self.isPolling = false
                    if !states.isEmpty, !MediaRemoteBridge.shared.isHealthy {
                        MediaManager.shared.handleSidecarPlayersUpdate(states)
                    }
                }
            }
        }
    }

    private nonisolated static func query(_ spec: PlayerSpec) -> RemoteMediaState? {
        let script = """
        tell application "\(spec.appName)"
            try
                set pstate to (player state as text)
                if pstate is "stopped" then return ""
                set trk to current track
                return pstate & "|||" & (name of trk) & "|||" & (artist of trk) & "|||" & (album of trk) & "|||" & ((duration of trk) as text) & "|||" & (player position as text)
            on error
                return ""
            end try
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let result = appleScript.executeAndReturnError(&error)
        guard error == nil, let raw = result.stringValue, !raw.isEmpty else { return nil }

        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        func number(_ s: String) -> Double {
            Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        let title = parts[1]
        guard !title.isEmpty else { return nil }
        let duration = number(parts[4]) / spec.durationDivisor
        let position = number(parts[5])

        return RemoteMediaState(
            key: "\(spec.bundleId)||\(spec.appName)|0",
            title: title,
            artist: parts[2],
            album: parts[3],
            duration: duration,
            position: position,
            isPlaying: parts[0].lowercased() == "playing",
            artworkPath: "",
            bundleIdentifier: spec.bundleId,
            parentBundleIdentifier: "",
            displayName: spec.appName
        )
    }
}
