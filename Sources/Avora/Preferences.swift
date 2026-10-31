import Foundation

/// A saved look: every export setting plus the backdrop, under a name.
struct StylePreset: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var settings: RenderSettings
    var backgroundID: String
}

/// User choices that outlive a launch.
final class Preferences: ObservableObject {
    static let backgroundKey = "background"
    static let settingsKey = "renderSettings"
    static let microphoneKey = "microphone"
    static let systemAudioKey = "systemAudio"
    static let captureModeKey = "captureMode"
    static let opensEditorKey = "opensEditorAfterRecording"
    static let afterRecordingKey = "afterRecording"
    static let presetsKey = "stylePresets"
    static let cameraKey = "camera"
    static let cameraPreviewKey = "showsCameraPreview"

    enum AfterRecording: String, CaseIterable {
        case reveal, copy, revealAndCopy
    }
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

    /// Unique ID of the camera; nil records no camera.
    @Published var cameraID: String? {
        didSet { defaults.set(cameraID, forKey: Self.cameraKey) }
    }

    @Published var showsCameraPreview: Bool {
        didSet { defaults.set(showsCameraPreview, forKey: Self.cameraPreviewKey) }
    }

    @Published var recordsSystemAudio: Bool {
        didSet { defaults.set(recordsSystemAudio, forKey: Self.systemAudioKey) }
    }

    @Published var opensEditorAfterRecording: Bool {
        didSet { defaults.set(opensEditorAfterRecording, forKey: Self.opensEditorKey) }
    }

    @Published private(set) var presets: [StylePreset] {
        didSet { defaults.set(try? JSONEncoder().encode(presets), forKey: Self.presetsKey) }
    }

    @Published var afterRecording: AfterRecording {
        didSet { defaults.set(afterRecording.rawValue, forKey: Self.afterRecordingKey) }
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
        cameraID = defaults.string(forKey: Self.cameraKey)
        showsCameraPreview = defaults.object(forKey: Self.cameraPreviewKey) as? Bool ?? true
        captureMode = defaults.string(forKey: Self.captureModeKey).flatMap(CaptureMode.init(rawValue:)) ?? .screen
        opensEditorAfterRecording = defaults.object(forKey: Self.opensEditorKey) as? Bool ?? true
        afterRecording = defaults.string(forKey: Self.afterRecordingKey).flatMap(AfterRecording.init(rawValue:)) ?? .reveal
        presets = defaults.data(forKey: Self.presetsKey).flatMap { try? JSONDecoder().decode([StylePreset].self, from: $0) } ?? []
    }

    /// Saving under a name that exists updates that preset in place.
    func savePreset(named name: String) {
        let preset = StylePreset(name: name, settings: settings, backgroundID: backgroundID)
        if let index = presets.firstIndex(where: { $0.name == name }) {
            presets[index].settings = preset.settings
            presets[index].backgroundID = preset.backgroundID
        } else {
            presets.append(preset)
        }
    }

    func apply(_ preset: StylePreset) {
        settings = preset.settings
        backgroundID = BackgroundPreset.named(preset.backgroundID).id
    }

    func deletePreset(_ preset: StylePreset) {
        presets.removeAll { $0.id == preset.id }
    }
}
