import Foundation
import AppKit

public struct RemoteMediaState: Sendable {
    public var key: String
    public var title: String
    public var artist: String
    public var album: String
    public var duration: Double
    public var position: Double
    public var isPlaying: Bool
    public var artworkPath: String
    public var bundleIdentifier: String
    public var parentBundleIdentifier: String
    public var displayName: String

    public init(
        key: String = "",
        title: String,
        artist: String,
        album: String,
        duration: Double,
        position: Double,
        isPlaying: Bool,
        artworkPath: String = "",
        bundleIdentifier: String,
        parentBundleIdentifier: String = "",
        displayName: String
    ) {
        self.key = key
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
        self.artworkPath = artworkPath
        self.bundleIdentifier = bundleIdentifier
        self.parentBundleIdentifier = parentBundleIdentifier
        self.displayName = displayName
    }
}

/// Bridges macOS MediaRemote.framework via a persistent Apple-signed `/usr/bin/swift` sidecar process.
/// On macOS 15.4+ (Sequoia / Tahoe), `mediaremoted` blocks direct XPC calls from non-Apple-signed binaries
/// (returning 0 clients and nil). Spawning `/usr/bin/swift` provides full platform-signed access to
/// `MRNowPlayingController`, real-time sub-second elapsed time, exact play/pause state, 600x600 thumbnails,
/// and direct background playback/seek commands (identical to Canopy and NotchNook).
public final class MediaRemoteBridge: @unchecked Sendable {
    public static let shared = MediaRemoteBridge()

    public private(set) var isAvailable: Bool = true
    public private(set) var latestPlayers: [RemoteMediaState] = []
    public var activeTargetKey: String = ""

    private var sidecarProcess: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var outputBuffer = Data()
    private let stateLock = NSLock()
    private let sidecarScriptPath = "/tmp/obelisk_mediaremote_sidecar.swift"
    private var isTerminating = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isTerminating = true
            self?.stopSidecar()
        }
        startSidecar()
    }

    private func writeSidecarScript() {
        let script = #"""
import Foundation
import ObjectiveC

setbuf(__stdoutp, nil)

guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
    exit(1)
}

typealias MRRegisterFn = @convention(c) (DispatchQueue) -> Void
typealias MRGetClientsFn = @convention(c) (DispatchQueue, @escaping (CFArray?) -> Void) -> Void
typealias MRGetPlayersFn = @convention(c) (AnyObject?, AnyObject?, DispatchQueue, @escaping (CFArray?) -> Void) -> Void
typealias MRSendCommandFn = @convention(c) (UInt32, AnyObject?) -> Bool

if let regSym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
    let regFn = unsafeBitCast(regSym, to: MRRegisterFn.self)
    regFn(DispatchQueue.main)
}

let getClients = unsafeBitCast(dlsym(handle, "MRMediaRemoteGetNowPlayingClients")!, to: MRGetClientsFn.self)
let getPlayers = unsafeBitCast(dlsym(handle, "MRMediaRemoteGetPlayersForClient")!, to: MRGetPlayersFn.self)
let globalSendCmd: MRSendCommandFn? = {
    guard let sym = dlsym(handle, "MRMediaRemoteSendCommand") else { return nil }
    return unsafeBitCast(sym, to: MRSendCommandFn.self)
}()

let originClass = NSClassFromString("MROrigin") as! NSObject.Type
let localOrigin = originClass.perform(NSSelectorFromString("localOrigin"))!.takeUnretainedValue() as! NSObject
let playerPathClass = NSClassFromString("MRPlayerPath") as! NSObject.Type
let destClass = NSClassFromString("MRDestination") as! NSObject.Type
let configClass = NSClassFromString("MRNowPlayingControllerConfiguration") as! NSObject.Type
let reqQueueClass = NSClassFromString("MRPlaybackQueueRequest") as! NSObject.Type
let controllerClass = NSClassFromString("MRNowPlayingController") as! NSObject.Type

typealias InitWithConfigFn = @convention(c) (AnyObject, Selector, AnyObject) -> NSObject
typealias PerformReqFn = @convention(c) (AnyObject, Selector, @escaping @convention(block) (NSObject?, NSError?) -> Void) -> Void
typealias SendCmdFn = @convention(c) (AnyObject, Selector, UInt32, NSDictionary?, @escaping @convention(block) (NSObject?) -> Void) -> Void

let initSel = NSSelectorFromString("initWithConfiguration:")
let reqSel = NSSelectorFromString("performRequestWithCompletion:")
let sendSel = NSSelectorFromString("sendCommand:options:completion:")

let initFn = unsafeBitCast(class_getMethodImplementation(controllerClass, initSel)!, to: InitWithConfigFn.self)
let reqFn = unsafeBitCast(class_getMethodImplementation(controllerClass, reqSel)!, to: PerformReqFn.self)
let sendFn = unsafeBitCast(class_getMethodImplementation(controllerClass, sendSel)!, to: SendCmdFn.self)

var controllers: [String: NSObject] = [:]
var lastArtTitleByKey: [String: String] = [:]
var lastArtPathByKey: [String: String] = [:]
var isPolling = false
var lastPollStartTime = Date.distantPast

let spotifyPosScript: NSAppleScript? = {
    let s = NSAppleScript(source: "tell application \"Spotify\" to if it is running then return (player position as real)")
    s?.compileAndReturnError(nil)
    return s
}()

let musicPosScript: NSAppleScript? = {
    let s = NSAppleScript(source: "tell application \"Music\" to if it is running then return (player position as real)")
    s?.compileAndReturnError(nil)
    return s
}()

func parseDouble(_ val: Any?) -> Double {
    if let d = val as? Double { return d }
    if let n = val as? NSNumber { return n.doubleValue }
    if let s = val as? String, let d = Double(s.replacingOccurrences(of: ",", with: ".")) { return d }
    return 0
}

func pollAllPlayers(forceArtwork: Bool = false) {
    let now = Date()
    if isPolling && !forceArtwork {
        if now.timeIntervalSince(lastPollStartTime) > 1.5 {
            isPolling = false
        } else {
            return
        }
    }
    isPolling = true
    lastPollStartTime = now

    getClients(DispatchQueue.main) { arr in
        guard let clients = arr as? [NSObject], !clients.isEmpty else {
            isPolling = false
            print("PLAYERS_JSON:[]")
            fflush(__stdoutp)
            return
        }

        let group = DispatchGroup()
        var results: [[String: Any]] = []
        var activeKeys = Set<String>()

        for c in clients {
            let bundleId = c.value(forKey: "bundleIdentifier") as? String ?? ""
            let parentId = c.value(forKey: "parentApplicationBundleIdentifier") as? String ?? ""
            let displayName = c.value(forKey: "displayName") as? String ?? ""

            group.enter()
            getPlayers(c, localOrigin, DispatchQueue.main) { pArr in
                guard let players = pArr as? [NSObject], !players.isEmpty else {
                    group.leave()
                    return
                }

                for (idx, pl) in players.enumerated() {
                    let key = "\(bundleId)|\(parentId)|\(displayName)|\(idx)"
                    activeKeys.insert(key)

                    let ctrl: NSObject
                    if let existing = controllers[key] {
                        ctrl = existing
                    } else {
                        let pp = playerPathClass.init()
                        pp.setValue(localOrigin, forKey: "origin")
                        pp.setValue(c, forKey: "client")
                        pp.setValue(pl, forKey: "player")

                        let dest = destClass.init()
                        dest.setValue(pp, forKey: "playerPath")

                        let qReq = reqQueueClass.perform(NSSelectorFromString("defaultPlaybackQueueRequest"))?.takeUnretainedValue() as? NSObject
                        qReq?.setValue(600.0, forKey: "artworkWidth")
                        qReq?.setValue(600.0, forKey: "artworkHeight")
                        qReq?.setValue(true, forKey: "includeMetadata")

                        let cfg = configClass.init()
                        cfg.setValue(dest, forKey: "destination")
                        cfg.setValue(true, forKey: "requestPlaybackState")
                        cfg.setValue(true, forKey: "requestPlaybackQueue")
                        cfg.setValue(true, forKey: "requestClientProperties")
                        if let qReq = qReq {
                            cfg.setValue(qReq, forKey: "playbackQueueRequest")
                        }

                        let raw = class_createInstance(controllerClass, 0) as AnyObject
                        let created = initFn(raw, initSel, cfg)
                        controllers[key] = created
                        ctrl = created
                    }

                    group.enter()
                    reqFn(ctrl, reqSel) { resp, _ in
                        defer { group.leave() }
                        guard let resp = resp,
                              let item = resp.value(forKey: "_mostRelevantItem") as? NSObject,
                              let meta = item.value(forKey: "metadata") as? NSObject else {
                            return
                        }

                        let title = meta.value(forKey: "title") as? String ?? ""
                        let artist = meta.value(forKey: "trackArtistName") as? String ?? ""
                        let album = meta.value(forKey: "albumName") as? String ?? ""
                        let dur = parseDouble(meta.value(forKey: "duration"))
                        let calc = parseDouble(meta.value(forKey: "calculatedPlaybackPosition"))
                        let el = parseDouble(meta.value(forKey: "elapsedTime"))
                        let rate = parseDouble(meta.value(forKey: "playbackRate"))
                        let pbState = (resp.value(forKey: "playbackState") as? NSNumber)?.intValue ?? 0

                        guard dur > 0 || !title.isEmpty else { return }

                        // Strict Play/Pause check:
                        // pbState == 1 is Playing (even if playbackRate momentarily dips to 0 while buffering after a skip/seek)
                        // pbState == 2 is Paused, 3 is Stopped, 4 is Interrupted
                        let isPlaying: Bool
                        if pbState == 1 {
                            isPlaying = true
                        } else if pbState == 2 || pbState == 3 || pbState == 4 {
                            isPlaying = false
                        } else {
                            isPlaying = (rate > 0)
                        }

                        var pos = isPlaying ? (calc > 0 ? calc : el) : (el > 0 ? el : calc)
                        if bundleId == "com.spotify.client" {
                            var err: NSDictionary?
                            if let desc = spotifyPosScript?.executeAndReturnError(&err), err == nil {
                                let directPos = desc.doubleValue
                                if directPos > 0 || (isPlaying && directPos >= 0) {
                                    pos = directPos
                                }
                            }
                        } else if bundleId == "com.apple.Music" {
                            var err: NSDictionary?
                            if let desc = musicPosScript?.executeAndReturnError(&err), err == nil {
                                let directPos = desc.doubleValue
                                if directPos > 0 || (isPlaying && directPos >= 0) {
                                    pos = directPos
                                }
                            }
                        }
                        if dur > 0 {
                            pos = min(max(pos, 0), dur)
                        }

                        let trackIdent = "\(title)_\(artist)"
                        if lastArtTitleByKey[key] != trackIdent {
                            lastArtTitleByKey[key] = trackIdent
                            lastArtPathByKey.removeValue(forKey: key)
                        }

                        var artPath = lastArtPathByKey[key] ?? ""
                        if let artObj = item.value(forKey: "artwork") as? NSObject,
                           let imgData = artObj.value(forKey: "imageData") as? Data,
                           !imgData.isEmpty {
                            let safeName = key
                                .replacingOccurrences(of: "/", with: "_")
                                .replacingOccurrences(of: "|", with: "_")
                                .replacingOccurrences(of: " ", with: "_")
                            let titleHash = String(abs(trackIdent.hashValue), radix: 16)
                            let path = "/tmp/obelisk_art_\(safeName)_\(titleHash).tiff"
                            try? imgData.write(to: URL(fileURLWithPath: path))
                            lastArtPathByKey[key] = path
                            artPath = path
                        }

                        results.append([
                            "key": key,
                            "bundleId": bundleId,
                            "parentBundleId": parentId,
                            "displayName": displayName,
                            "title": title,
                            "artist": artist,
                            "album": album,
                            "duration": dur,
                            "position": pos,
                            "isPlaying": isPlaying,
                            "artworkPath": artPath
                        ])
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            isPolling = false
            for existingKey in Array(controllers.keys) {
                if !activeKeys.contains(existingKey) {
                    controllers.removeValue(forKey: existingKey)
                    lastArtTitleByKey.removeValue(forKey: existingKey)
                    lastArtPathByKey.removeValue(forKey: existingKey)
                }
            }
            if let data = try? JSONSerialization.data(withJSONObject: results),
               let str = String(data: data, encoding: .utf8) {
                print("PLAYERS_JSON:\(str)")
                fflush(__stdoutp)
            }
        }
    }
}

func executeCommandLine(_ line: String) {
    let parts = line.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|||")
    guard parts.count >= 4, parts[0] == "CMD" else { return }
    let targetKey = parts[1]
    let cmdInt = UInt32(parts[2]) ?? 2
    let paramVal = Double(parts[3]) ?? 0

    var ctrl: NSObject? = controllers[targetKey]
    if ctrl == nil && !targetKey.isEmpty {
        let subparts = targetKey.components(separatedBy: "|")
        let targetBundle = subparts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let targetName = subparts.count > 2 ? subparts[2].trimmingCharacters(in: .whitespacesAndNewlines) : ""

        // 1. Match by Bundle ID prefix
        if !targetBundle.isEmpty {
            for (k, v) in controllers {
                let kBundle = k.components(separatedBy: "|").first ?? ""
                if kBundle.lowercased() == targetBundle.lowercased() {
                    ctrl = v
                    break
                }
            }
        }

        // 2. Match by Display Name
        if ctrl == nil && !targetName.isEmpty {
            for (k, v) in controllers {
                if k.localizedCaseInsensitiveContains(targetName) {
                    ctrl = v
                    break
                }
            }
        }

        // 3. Match by partial substring
        if ctrl == nil {
            for (k, v) in controllers {
                if k.localizedCaseInsensitiveContains(targetKey) || targetKey.localizedCaseInsensitiveContains(k) {
                    ctrl = v
                    break
                }
            }
        }
    }

    if ctrl == nil && targetKey.isEmpty {
        ctrl = controllers.values.first
    }

    var opts: NSDictionary? = nil
    if cmdInt == 24 {
        opts = ["kMRMediaRemoteOptionPlaybackPosition": NSNumber(value: paramVal)]
    } else if cmdInt == 17 || cmdInt == 18 {
        opts = ["kMRMediaRemoteOptionSkipInterval": NSNumber(value: abs(paramVal))]
    }

    if let ctrl = ctrl {
        sendFn(ctrl, sendSel, cmdInt, opts) { _ in
            for delay in [0.08, 0.25] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    pollAllPlayers(forceArtwork: false)
                }
            }
        }
    } else if targetKey.isEmpty {
        _ = globalSendCmd?(cmdInt, opts)
        for delay in [0.08, 0.25] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                pollAllPlayers(forceArtwork: false)
            }
        }
    }
}

var stdinBuffer = Data()
FileHandle.standardInput.readabilityHandler = { handle in
    let chunk = handle.availableData
    if chunk.isEmpty {
        exit(0)
    }
    stdinBuffer.append(chunk)
    while let range = stdinBuffer.range(of: Data([0x0A])) {
        let lineData = stdinBuffer.subdata(in: 0..<range.lowerBound)
        stdinBuffer.removeSubrange(0..<range.upperBound)
        if let line = String(data: lineData, encoding: .utf8) {
            DispatchQueue.main.async {
                executeCommandLine(line)
            }
        }
    }
}

NotificationCenter.default.addObserver(
    forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
    object: nil,
    queue: .main
) { _ in
    pollAllPlayers(forceArtwork: false)
}

NotificationCenter.default.addObserver(
    forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
    object: nil,
    queue: .main
) { _ in
    pollAllPlayers(forceArtwork: false)
}

pollAllPlayers(forceArtwork: true)

let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
    pollAllPlayers(forceArtwork: false)
}
RunLoop.main.add(timer, forMode: .common)
RunLoop.main.run()
"""#
        try? script.write(toFile: sidecarScriptPath, atomically: true, encoding: .utf8)
    }

    private func startSidecar() {
        stopSidecar()
        writeSidecarScript()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        proc.arguments = [sidecarScriptPath]

        let inPipe = Pipe()
        let outPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = FileHandle.nullDevice

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.handleStdoutChunk(data)
        }

        proc.terminationHandler = { [weak self] _ in
            guard let self = self, !self.isTerminating else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, !self.isTerminating else { return }
                self.startSidecar()
            }
        }

        do {
            try proc.run()
            self.sidecarProcess = proc
            self.stdinPipe = inPipe
            self.stdoutPipe = outPipe
        } catch {
            self.isAvailable = false
        }
    }

    private func stopSidecar() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        if let proc = sidecarProcess, proc.isRunning {
            proc.terminate()
        }
        sidecarProcess = nil
        stdinPipe = nil
        stdoutPipe = nil
    }

    private func handleStdoutChunk(_ chunk: Data) {
        stateLock.lock()
        outputBuffer.append(chunk)
        var lines: [String] = []
        while let newlineRange = outputBuffer.range(of: Data([0x0A])) {
            let lineData = outputBuffer.subdata(in: 0..<newlineRange.lowerBound)
            outputBuffer.removeSubrange(0..<newlineRange.upperBound)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
        }
        stateLock.unlock()

        for line in lines {
            if line.hasPrefix("PLAYERS_JSON:") {
                let jsonStr = String(line.dropFirst("PLAYERS_JSON:".count))
                parseAndPublishPlayersJSON(jsonStr)
            }
        }
    }

    private func parseAndPublishPlayersJSON(_ jsonStr: String) {
        guard let data = jsonStr.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        var parsed: [RemoteMediaState] = []
        for item in arr {
            let key = item["key"] as? String ?? ""
            let bundleId = item["bundleId"] as? String ?? ""
            let parentId = item["parentBundleId"] as? String ?? ""
            let displayName = item["displayName"] as? String ?? ""
            let title = item["title"] as? String ?? ""
            let artist = item["artist"] as? String ?? ""
            let album = item["album"] as? String ?? ""
            let duration = (item["duration"] as? NSNumber)?.doubleValue ?? (item["duration"] as? Double ?? 0)
            let position = (item["position"] as? NSNumber)?.doubleValue ?? (item["position"] as? Double ?? 0)
            let isPlaying = (item["isPlaying"] as? Bool) ?? ((item["isPlaying"] as? NSNumber)?.boolValue ?? false)
            let artworkPath = item["artworkPath"] as? String ?? ""

            parsed.append(
                RemoteMediaState(
                    key: key,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    position: position,
                    isPlaying: isPlaying,
                    artworkPath: artworkPath,
                    bundleIdentifier: bundleId,
                    parentBundleIdentifier: parentId,
                    displayName: displayName
                )
            )
        }

        stateLock.lock()
        self.latestPlayers = parsed
        stateLock.unlock()

        Task { @MainActor in
            MediaManager.shared.handleSidecarPlayersUpdate(parsed)
        }
    }

    public func getLatestPlayers() -> [RemoteMediaState] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return latestPlayers
    }

    // MARK: - Command Dispatch to Sidecar
    public func sendSidecarCommand(targetKey: String? = nil, command: UInt32, parameter: Double = 0) {
        let keyToUse = targetKey ?? activeTargetKey
        let line = "CMD|||\(keyToUse)|||\(command)|||\(parameter)\n"
        guard let data = line.data(using: .utf8) else { return }

        stateLock.lock()
        defer { stateLock.unlock() }

        if sidecarProcess == nil || !(sidecarProcess?.isRunning ?? false) {
            startSidecar()
        }

        do {
            try stdinPipe?.fileHandleForWriting.write(contentsOf: data)
        } catch {
            // Broken pipe or crashed sidecar, restart and retry once
            startSidecar()
            try? stdinPipe?.fileHandleForWriting.write(contentsOf: data)
        }
    }

    public func play(targetKey: String? = nil) {
        sendSidecarCommand(targetKey: targetKey, command: 0, parameter: 0)
    }

    public func pause(targetKey: String? = nil) {
        sendSidecarCommand(targetKey: targetKey, command: 1, parameter: 0)
    }

    public func togglePlayPause(targetKey: String? = nil) {
        sendSidecarCommand(targetKey: targetKey, command: 2, parameter: 0)
    }

    public func nextTrack(targetKey: String? = nil) {
        sendSidecarCommand(targetKey: targetKey, command: 4, parameter: 0)
    }

    public func previousTrack(targetKey: String? = nil) {
        sendSidecarCommand(targetKey: targetKey, command: 5, parameter: 0)
    }

    public func skipForward15(targetKey: String? = nil) {
        sendSidecarCommand(targetKey: targetKey, command: 17, parameter: 15.0)
    }

    public func skipBackward15(targetKey: String? = nil) {
        sendSidecarCommand(targetKey: targetKey, command: 18, parameter: 15.0)
    }

    public func setElapsedTime(_ seconds: Double, targetKey: String? = nil) {
        sendSidecarCommand(targetKey: targetKey, command: 24, parameter: seconds)
    }
}
