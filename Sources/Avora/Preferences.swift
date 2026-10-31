import Foundation

/// User choices that outlive a launch.
final class Preferences: ObservableObject {
    static let backgroundKey = "background"
    static let settingsKey = "renderSettings"
    static let microphoneKey = "microphone"
    static let systemAudioKey = "systemAudio"
    static let captureModeKey = "captureMode"
    static let opensEditorKey = "opensEditorAfterRecording"
    static let shared = Preferences(defaults: .standard)

    @Published var backgroundID: String {
        didSet { defaults.set(backgroundID, forKey: Self.backgroundKey) }
    }

    @Published var settings: RenderSettings {
        didSet { defaults.set(try? JSONEncoder().encode(settings), forKey: Self.settingsKey) }
    }

    /// Unique ID of the capture device; nil records no microphone.
    @Published var microphoneID: String? {
        didSet { defaults.set(microphoneID, forKey: Self.microphoneKey) }
    }

    @Published var recordsSystemAudio: Bool {
        didSet { defaults.set(recordsSystemAudio, forKey: Self.systemAudioKey) }
    }

    @Published var opensEditorAfterRecording: Bool {
        didSet { defaults.set(opensEditorAfterRecording, forKey: Self.opensEditorKey) }
    }

    @Published var captureMode: CaptureMode {
        didSet { defaults.set(captureMode.rawValue, forKey: Self.captureModeKey) }
    }

    var background: BackgroundPreset { .named(backgroundID) }
    var outputStyle: OutputStyle { OutputStyle(settings: settings, background: background) }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        backgroundID = BackgroundPreset.named(defaults.string(forKey: Self.backgroundKey)).id
        settings = defaults.data(forKey: Self.settingsKey).flatMap { try? JSONDecoder().decode(RenderSettings.self, from: $0) }
            ?? RenderSettings()
        microphoneID = defaults.string(forKey: Self.microphoneKey)
        recordsSystemAudio = defaults.bool(forKey: Self.systemAudioKey)
        captureMode = defaults.string(forKey: Self.captureModeKey).flatMap(CaptureMode.init(rawValue:)) ?? .screen
        opensEditorAfterRecording = defaults.bool(forKey: Self.opensEditorKey)
    }
}
