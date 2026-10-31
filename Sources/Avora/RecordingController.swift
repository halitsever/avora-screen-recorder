import AppKit
import ScreenCaptureKit
import ZoomEngine

enum PermissionError: LocalizedError {
    case screenRecording

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!

    var errorDescription: String? {
        "Avora needs Screen Recording permission. Enable it in System Settings > Privacy & Security > Screen & System Audio Recording, then start again."
    }
}

/// Wall-clock time spent recording, without pauses, for the timers in the menu bar and window.
struct RecordingTimer: Equatable {
    var started: Date
    var pausedAt: Date?
    var pausedTotal: TimeInterval = 0

    var isPaused: Bool { pausedAt != nil }

    func elapsed(at now: Date = Date()) -> TimeInterval {
        max((pausedAt ?? now).timeIntervalSince(started) - pausedTotal, 0)
    }
}

@MainActor
final class RecordingController: ObservableObject {
    enum State: Equatable {
        case idle
        case starting
        case recording(RecordingTimer)
        case rendering(progress: Double)
    }

    @Published private(set) var state = State.idle {
        didSet { onChange?() }
    }
    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?
    /// Called with the raw recording after its video is saved.
    var onFinished: ((RecordingFolder) -> Void)?

    private var session: Session?
    private var checkpoints: Task<Void, Never>?

    /// Everything that runs while one recording is in progress.
    private struct Session {
        let folder: RecordingFolder
        let target: CaptureTarget
        let clock: RecordingClock
        let input: InputRecorder
        let screen: ScreenRecorder
        let microphone: MicrophoneRecorder?
        let camera: CameraRecorder?
        let cameraWriter: CameraTrackWriter?
        let cameraPreview: CameraPreviewPanel?
        let window: WindowTracker?
        let keystrokes: KeystrokeRecorder?
        let audio: [(writer: AudioTrackWriter, kind: AudioManifest.Kind)]
    }

    func toggle() async {
        switch state {
        case .idle: await start()
        case .recording: await stop()
        case .starting, .rendering: break
        }
    }

    /// `reusing` records the same display, window or area again without asking.
    func start(reusing given: CaptureTarget? = nil) async {
        guard state == .idle else { return }
        state = .starting
        var created: RecordingFolder?
        // A start that fails leaves nothing behind to clean up later.
        defer { if state == .idle, let created { try? FileManager.default.removeItem(at: created.url) } }
        do {
            let folder = try RecordingFolder.makeNew()
            created = folder
            let preferences = Preferences.shared
            let clock = RecordingClock()
            let target: CaptureTarget
            if let given {
                target = given
            } else if preferences.captureMode == .screen {
                target = try await CaptureTarget.current()
            } else {
                guard let picked = await SelectionOverlay.pick(preferences.captureMode) else {
                    state = .idle
                    return
                }
                if let window = picked.window {
                    NSRunningApplication(processIdentifier: window.owner)?.activate()
                    target = try await CaptureTarget.window(window.id)
                } else {
                    target = try await CaptureTarget.area(picked.rect)
                }
            }

            var audio: [(writer: AudioTrackWriter, kind: AudioManifest.Kind)] = []
            var microphone: MicrophoneRecorder?
            if let deviceID = preferences.microphoneID {
                let writer = AudioTrackWriter(url: folder.microphone)
                microphone = try await MicrophoneRecorder(deviceID: deviceID, clock: clock, writer: writer)
                audio.append((writer, .microphone))
            }
            var camera: CameraRecorder?
            var cameraWriter: CameraTrackWriter?
            if let deviceID = preferences.cameraID {
                let writer = CameraTrackWriter(url: folder.camera)
                camera = try await CameraRecorder(deviceID: deviceID, clock: clock, writer: writer)
                cameraWriter = writer
            }
            let cameraPreview = camera.flatMap { preferences.showsCameraPreview ? CameraPreviewPanel(session: $0.session) : nil }
            let systemAudio = preferences.recordsSystemAudio ? AudioTrackWriter(url: folder.systemAudio) : nil
            if let systemAudio { audio.append((systemAudio, .system)) }

            let tracker = target.windowID.map { WindowTracker(windowID: $0, frame: target.bounds) }
            tracker?.start()
            let input = InputRecorder(displayBounds: target.bounds, scale: target.scale, window: tracker, pixelSize: target.pixelSize)
            let screen = ScreenRecorder(clock: clock, systemAudio: systemAudio)
            let wantsKeys = preferences.settings.showsShortcuts || preferences.settings.notesTyping
            let keystrokes = wantsKeys ? KeystrokeRecorder(notesTyping: preferences.settings.notesTyping) : nil
            input.start()
            keystrokes?.start()
            microphone?.start()
            camera?.start()
            cameraPreview?.show()
            do {
                try await screen.start(target, to: folder.video)
            } catch {
                input.stop()
                keystrokes?.stop()
                microphone?.stop()
                camera?.stop()
                cameraPreview?.close()
                tracker?.stop()
                throw error
            }
            session = Session(folder: folder, target: target, clock: clock, input: input, screen: screen,
                              microphone: microphone, camera: camera, cameraWriter: cameraWriter, cameraPreview: cameraPreview,
                              window: tracker, keystrokes: keystrokes, audio: audio)
            state = .recording(RecordingTimer(started: Date()))
            checkpoints = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    self?.saveCheckpoint()
                }
            }
        } catch let error as SCStreamError where error.code == .userDeclined {
            state = .idle
            onError?(PermissionError.screenRecording)
            NSWorkspace.shared.open(PermissionError.settingsURL)
        } catch MicrophoneError.denied {
            state = .idle
            onError?(MicrophoneError.denied)
            NSWorkspace.shared.open(MicrophoneError.settingsURL)
        } catch CameraError.denied {
            state = .idle
            onError?(CameraError.denied)
            NSWorkspace.shared.open(CameraError.settingsURL)
        } catch {
            state = .idle
            onError?(error)
        }
    }

    func togglePause() {
        guard case .recording(var timer) = state, let session else { return }
        if let pausedAt = timer.pausedAt {
            session.clock.resume()
            session.screen.resumed()
            timer.pausedTotal += Date().timeIntervalSince(pausedAt)
            timer.pausedAt = nil
        } else {
            session.clock.pause()
            timer.pausedAt = Date()
        }
        state = .recording(timer)
    }

    /// Writes what is known so far, so a crash leaves a recording that can be recovered.
    private func saveCheckpoint() {
        guard let session, let start = session.screen.startTime else { return }
        let folder = session.folder
        let end = session.clock.recordingTime(endingAt: HostClock.now())
        if let log = try? session.input.makeLog(clock: session.clock, videoStart: start, videoEnd: end,
                                                 sourceSize: session.target.pixelSize, cursorFolder: folder.cursors) {
            try? JSONEncoder().encode(log).write(to: folder.partialLog, options: .atomic)
        }
        let tracks = session.audio.compactMap { writer, kind in
            writer.startTime.map { AudioManifest.Track(file: writer.url.lastPathComponent, kind: kind, offset: $0 - start) }
        }
        if !tracks.isEmpty { try? JSONEncoder().encode(AudioManifest(tracks: tracks)).write(to: folder.audioManifest, options: .atomic) }
        if let cameraStart = session.cameraWriter?.startTime {
            try? JSONEncoder().encode(CameraManifest(file: folder.camera.lastPathComponent, offset: cameraStart - start))
                .write(to: folder.cameraManifest, options: .atomic)
        }
        if let keys = session.keystrokes?.presses(clock: session.clock, videoStart: start), !keys.isEmpty {
            try? JSONEncoder().encode(keys).write(to: folder.keys, options: .atomic)
        }
        if let typing = session.keystrokes?.typingTimes(clock: session.clock, videoStart: start), !typing.isEmpty {
            try? JSONEncoder().encode(typing).write(to: folder.typing, options: .atomic)
        }
    }

    /// Turns a recording cut short by a crash into a video, from what was saved along the way.
    func recover(_ folder: RecordingFolder) async {
        guard state == .idle else { return }
        state = .rendering(progress: 0)
        defer { state = .idle }
        do {
            try RawRecordings.markRecovered(folder)
            let style = Preferences.shared.outputStyle
            let movie = try RecordingFolder.newMovieURL(fileExtension: style.format.fileExtension)
            try await Exporter.export(folder, to: movie, style: style) { value in
                Task { @MainActor in
                    if case .rendering = self.state { self.state = .rendering(progress: value) }
                }
            }
            NSWorkspace.shared.activateFileViewerSelecting([movie])
        } catch {
            onError?(error)
        }
    }

    /// Throws the take away. With `restart` a new take of the same target begins right after.
    func discard(restart: Bool) async {
        guard case .recording = state, let session else { return }
        checkpoints?.cancel()
        state = .starting
        _ = try? await session.screen.stop()
        session.keystrokes?.stop()
        session.microphone?.stop()
        session.camera?.stop()
        session.cameraPreview?.close()
        _ = await session.cameraWriter?.finish()
        session.input.stop()
        session.window?.stop()
        for (writer, _) in session.audio { _ = await writer.finish() }
        try? FileManager.default.removeItem(at: session.folder.url)
        self.session = nil
        state = .idle
        if restart { await start(reusing: session.target) }
    }

    func stop() async {
        guard case .recording = state, let session else { return }
        checkpoints?.cancel()
        state = .rendering(progress: 0)
        defer {
            self.session = nil
            state = .idle
        }
        do {
            let folder = session.folder
            let timing = try await session.screen.stop()
            session.keystrokes?.stop()
            if let keys = session.keystrokes?.presses(clock: session.clock, videoStart: timing.start), !keys.isEmpty {
                try JSONEncoder().encode(keys).write(to: folder.keys)
            }
            if let typing = session.keystrokes?.typingTimes(clock: session.clock, videoStart: timing.start), !typing.isEmpty {
                try JSONEncoder().encode(typing).write(to: folder.typing)
            }
            session.microphone?.stop()
            session.camera?.stop()
            session.cameraPreview?.close()
            if let start = await session.cameraWriter?.finish() {
                try JSONEncoder().encode(CameraManifest(file: folder.camera.lastPathComponent, offset: start - timing.start))
                    .write(to: folder.cameraManifest)
            }
            session.input.stop()
            session.window?.stop()

            var tracks: [AudioManifest.Track] = []
            for (writer, kind) in session.audio {
                if let start = await writer.finish() {
                    tracks.append(.init(file: writer.url.lastPathComponent, kind: kind, offset: start - timing.start))
                }
            }
            if !tracks.isEmpty { try JSONEncoder().encode(AudioManifest(tracks: tracks)).write(to: folder.audioManifest) }
            if var camera = folder.loadCamera(), tracks.contains(where: { $0.kind == .microphone }),
               let lag = await Task.detached(priority: .userInitiated, operation: { await LipSync.measure(folder) }).value {
                camera.sync = lag
                try JSONEncoder().encode(camera).write(to: folder.cameraManifest)
            }

            let log = try session.input.makeLog(clock: session.clock, videoStart: timing.start, videoEnd: timing.end,
                                                sourceSize: session.target.pixelSize, cursorFolder: folder.cursors)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(log).write(to: folder.log)
            try? FileManager.default.removeItem(at: folder.partialLog)

            let style = Preferences.shared.outputStyle
            let movie = try RecordingFolder.newMovieURL(fileExtension: style.format.fileExtension)
            try await Exporter.export(folder, to: movie, style: style) { value in
                Task { @MainActor in
                    if case .rendering = self.state { self.state = .rendering(progress: value) }
                }
            }
            let after = Preferences.shared.afterRecording
            if after != .copy { NSWorkspace.shared.activateFileViewerSelecting([movie]) }
            if after != .reveal { Clipboard.copy(file: movie) }
            onFinished?(folder)
            Task.detached(priority: .utility) { RawRecordings.removeExpired() }
        } catch {
            onError?(error)
        }
    }
}
