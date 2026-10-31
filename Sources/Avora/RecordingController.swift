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

@MainActor
final class RecordingController: ObservableObject {
    enum State: Equatable {
        case idle
        case starting
        case recording(since: Date)
        case rendering(progress: Double)
    }

    @Published private(set) var state = State.idle {
        didSet { onChange?() }
    }
    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?

    private var screen: ScreenRecorder?
    private var input: InputRecorder?
    private var target: CaptureTarget?
    private var folder: RecordingFolder?

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
        do {
            let folder = try RecordingFolder.makeNew()
            let target = try await CaptureTarget.current()
            let input = InputRecorder(displayBounds: target.bounds, scale: target.scale)
            let screen = ScreenRecorder()
            input.start()
            do {
                try await screen.start(target, to: folder.video)
            } catch {
                input.stop()
                throw error
            }
            (self.folder, self.target, self.input, self.screen) = (folder, target, input, screen)
            state = .recording(since: Date())
        } catch let error as SCStreamError where error.code == .userDeclined {
            state = .idle
            onError?(PermissionError.screenRecording)
            NSWorkspace.shared.open(PermissionError.settingsURL)
        } catch {
            state = .idle
            onError?(error)
        }
    }

    func stop() async {
        guard case .recording = state, let screen, let input, let target, let folder else { return }
        state = .rendering(progress: 0)
        defer {
            (self.screen, self.input, self.target, self.folder) = (nil, nil, nil, nil)
            state = .idle
        }
        do {
            let timing = try await screen.stop()
            input.stop()
            let log = try input.makeLog(videoStart: timing.start, videoEnd: timing.end,
                                        sourceSize: target.pixelSize, cursorFolder: folder.cursors)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(log).write(to: folder.log)

            let movie = try RecordingFolder.newMovieURL()
            let style = OutputStyle(background: Preferences.shared.background)
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
}
