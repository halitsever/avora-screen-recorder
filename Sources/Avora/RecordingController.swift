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

    /// Everything that runs while one recording is in progress.
    private struct Session {
        let folder: RecordingFolder
        let target: CaptureTarget
        let clock: RecordingClock
        let input: InputRecorder
        let screen: ScreenRecorder
        let microphone: MicrophoneRecorder?
        let audio: [(writer: AudioTrackWriter, kind: AudioManifest.Kind)]
    }

    func toggle() async {
        switch state {
        case .idle: await start()
        case .recording: await stop()
        case .starting, .rendering: break
        }
    }

    func start() async {
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
            switch preferences.captureMode {
            case .screen:
                target = try await CaptureTarget.current()
            case .window, .area:
                guard let picked = await SelectionOverlay.pick(preferences.captureMode) else {
                    state = .idle
                    return
                }
                if let owner = picked.windowOwner {
                    NSRunningApplication(processIdentifier: owner)?.activate()
                    // Give the window a moment to come forward before the first frame.
                    try await Task.sleep(for: .milliseconds(250))
                }
                target = try await CaptureTarget.area(picked.rect)
            }

            var audio: [(writer: AudioTrackWriter, kind: AudioManifest.Kind)] = []
            var microphone: MicrophoneRecorder?
            if let deviceID = preferences.microphoneID {
                let writer = AudioTrackWriter(url: folder.microphone)
                microphone = try await MicrophoneRecorder(deviceID: deviceID, clock: clock, writer: writer)
                audio.append((writer, .microphone))
            }
            let systemAudio = preferences.recordsSystemAudio ? AudioTrackWriter(url: folder.systemAudio) : nil
            if let systemAudio { audio.append((systemAudio, .system)) }

            let input = InputRecorder(displayBounds: target.bounds, scale: target.scale)
            let screen = ScreenRecorder(clock: clock, systemAudio: systemAudio)
            input.start()
            microphone?.start()
            do {
                try await screen.start(target, to: folder.video)
            } catch {
                input.stop()
                microphone?.stop()
                throw error
            }
            session = Session(folder: folder, target: target, clock: clock, input: input, screen: screen,
                              microphone: microphone, audio: audio)
            state = .recording(RecordingTimer(started: Date()))
        } catch let error as SCStreamError where error.code == .userDeclined {
            state = .idle
            onError?(PermissionError.screenRecording)
            NSWorkspace.shared.open(PermissionError.settingsURL)
        } catch MicrophoneError.denied {
            state = .idle
            onError?(MicrophoneError.denied)
            NSWorkspace.shared.open(MicrophoneError.settingsURL)
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

    func stop() async {
        guard case .recording = state, let session else { return }
        state = .rendering(progress: 0)
        defer {
            self.session = nil
            state = .idle
        }
        do {
            let folder = session.folder
            let timing = try await session.screen.stop()
            session.microphone?.stop()
            session.input.stop()

            var tracks: [AudioManifest.Track] = []
            for (writer, kind) in session.audio {
                if let start = await writer.finish() {
                    tracks.append(.init(file: writer.url.lastPathComponent, kind: kind, offset: start - timing.start))
                }
            }
            if !tracks.isEmpty { try JSONEncoder().encode(AudioManifest(tracks: tracks)).write(to: folder.audioManifest) }

            let log = try session.input.makeLog(clock: session.clock, videoStart: timing.start, videoEnd: timing.end,
                                                sourceSize: session.target.pixelSize, cursorFolder: folder.cursors)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(log).write(to: folder.log)

            let style = Preferences.shared.outputStyle
            let movie = try RecordingFolder.newMovieURL(fileExtension: style.format.fileExtension)
            try await Exporter.export(folder, to: movie, style: style) { value in
                Task { @MainActor in
                    if case .rendering = self.state { self.state = .rendering(progress: value) }
                }
            }
            NSWorkspace.shared.activateFileViewerSelecting([movie])
            onFinished?(folder)
            Task.detached(priority: .utility) { RawRecordings.removeExpired() }
        } catch {
            onError?(error)
        }
    }
}
