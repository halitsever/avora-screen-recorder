import AVFoundation
import AppKit
import Speech
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences

    private var settings: Binding<RenderSettings> { $preferences.settings }
    private var format: RenderSettings.Format { preferences.settings.format }
    @State private var microphones = MicrophoneRecorder.devices

    var body: some View {
        TabView {
            Form {
                Section("Audio") {
                    Picker("Microphone", selection: $preferences.microphoneID) {
                        Text("Off").tag(String?.none)
                        ForEach(microphones, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(String?.some(device.uniqueID))
                        }
                    }
                    Picker("Voice", selection: $preferences.settings.voice) {
                        Text("As recorded").tag(VoicePreset.off)
                        Text("Even level").tag(VoicePreset.standard)
                        Text("Clear: remove background noise").tag(VoicePreset.clear)
                    }
                    .disabled(preferences.microphoneID == nil)
                    Toggle("Record system audio", isOn: $preferences.recordsSystemAudio)
                    if preferences.microphoneID != nil {
                        Text("The voice is processed on this Mac when the video is exported.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                CameraSection(preferences: preferences)
                CaptionSection(preferences: preferences)
                Section("Keyboard") {
                    Toggle("Show keyboard shortcuts", isOn: Binding(get: { preferences.settings.showsShortcuts }, set: { on in
                        preferences.settings.showsShortcuts = on
                        if on { KeystrokeRecorder.requestAccess() }
                    }))
                    Toggle("Note when you type", isOn: Binding(get: { preferences.settings.notesTyping }, set: { on in
                        preferences.settings.notesTyping = on
                        if on { KeystrokeRecorder.requestAccess() }
                    }))
                    Text("Only shortcuts with ⌘, ⌃ or ⌥ are shown. For typing, Avora notes when keys are pressed, never which, so the editor can speed it up. Both need Accessibility access.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("After Recording") {
                    Picker("Finished video", selection: $preferences.afterRecording) {
                        Text("Show in Finder").tag(Preferences.AfterRecording.reveal)
                        Text("Copy to clipboard").tag(Preferences.AfterRecording.copy)
                        Text("Show and copy").tag(Preferences.AfterRecording.revealAndCopy)
                    }
                    Toggle("Open the editor", isOn: $preferences.opensEditorAfterRecording)
                    Text("A copied video pastes straight into a chat or an email. Edit Last Recording in the menu opens the editor any time within 7 days.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Recording", systemImage: "record.circle") }

            Form {
                BackdropSection(preferences: preferences)
                Section("Motion") {
                    SliderRow("Zoom", value: settings.zoom, in: 1.25...3, step: 0.25) { String(format: "%g×", $0) }
                    SliderRow("Motion blur", value: settings.motionBlur, in: 0...1) { "\(Int(($0 * 100).rounded()))%" }
                }
                Section("Frame") {
                    SliderRow("Padding", value: settings.padding, in: 0...0.25) { "\(Int(($0 * 100).rounded()))%" }
                    SliderRow("Corners", value: settings.cornerRadius, in: 0...0.03) { "\(Int(($0 / 0.03 * 100).rounded()))%" }
                    SliderRow("Shadow", value: settings.shadow, in: 0...0.6) { "\(Int(($0 / 0.6 * 100).rounded()))%" }
                }
                Section("Cursor") {
                    Toggle("Show the cursor", isOn: settings.showsCursor)
                    Picker("Click effect", selection: settings.clickEffect) {
                        Text("None").tag(RenderSettings.ClickEffect.none)
                        Text("Circle").tag(RenderSettings.ClickEffect.circle)
                        Text("Ripple").tag(RenderSettings.ClickEffect.ripple)
                    }
                    .disabled(!preferences.settings.showsCursor)
                    Toggle("Hide after 2 s without moving", isOn: settings.hidesIdleCursor)
                        .disabled(!preferences.settings.showsCursor)
                    SliderRow("Hold still at the end", value: settings.cursorFreeze, in: 0...5, step: 0.5) { $0 == 0 ? "Off" : String(format: "%g s", $0) }
                    SliderRow("Size", value: settings.cursorScale, in: 1...3, step: 0.25) { String(format: "%g×", $0) }
                    Picker("Smoothing", selection: settings.smoothing) {
                        Text("Smooth").tag(RenderSettings.Smoothing.smooth)
                        Text("Medium").tag(RenderSettings.Smoothing.medium)
                        Text("Rapid").tag(RenderSettings.Smoothing.rapid)
                        Text("Off").tag(RenderSettings.Smoothing.none)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Look", systemImage: "paintpalette") }

            Form {
                Section("Video") {
                    Picker("Format", selection: settings.format) {
                        Text("MP4 (H.264)").tag(RenderSettings.Format.h264)
                        Text("MP4 (HEVC)").tag(RenderSettings.Format.hevc)
                        Text("ProRes 422 HQ").tag(RenderSettings.Format.prores)
                        Text("GIF").tag(RenderSettings.Format.gif)
                    }
                    Picker("Shape", selection: settings.aspect) {
                        Text("Same as recording").tag(RenderSettings.Aspect.auto)
                        Text("16:9 Widescreen").tag(RenderSettings.Aspect.wide)
                        Text("4:3").tag(RenderSettings.Aspect.classic)
                        Text("1:1 Square").tag(RenderSettings.Aspect.square)
                        Text("4:5 Feed").tag(RenderSettings.Aspect.feed)
                        Text("3:4").tag(RenderSettings.Aspect.portrait)
                        Text("9:16 Stories and Reels").tag(RenderSettings.Aspect.vertical)
                    }
                    Picker("Resolution", selection: settings.resolution) {
                        Text("Same as recording").tag(RenderSettings.Resolution.source)
                        Text("4K").tag(RenderSettings.Resolution.uhd)
                        Text("1080p").tag(RenderSettings.Resolution.fullHD)
                        Text("720p").tag(RenderSettings.Resolution.hd)
                    }
                    Picker("Frame rate", selection: settings.fps) {
                        Text("60 fps").tag(60)
                        Text("30 fps").tag(30)
                    }
                    .disabled(format == .gif)
                    Picker("Quality", selection: settings.quality) {
                        Text("Studio").tag(RenderSettings.Quality.studio)
                        Text("Social").tag(RenderSettings.Quality.social)
                        Text("Web").tag(RenderSettings.Quality.web)
                    }
                    .disabled(format == .prores || format == .gif)
                    if format == .gif {
                        Text("GIFs are 15 fps and at most 960 pixels wide.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Presets") {
                    ForEach(preferences.presets) { preset in
                        HStack {
                            Text(preset.name)
                            Spacer()
                            Button("Apply") { preferences.apply(preset) }
                            Button { preferences.deletePreset(preset) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                                .help("Delete \(preset.name)")
                        }
                    }
                    Button("Save Current Look…") { askForPresetName() }
                }
                Section {
                    HStack {
                        Text("Applies to the next video. Re-render older recordings with `Avora render`.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore Defaults") { preferences.settings = RenderSettings() }
                            .disabled(preferences.settings == RenderSettings())
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in
            microphones = MicrophoneRecorder.devices
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in
            microphones = MicrophoneRecorder.devices
        }
        // Tabs keep the window a sensible size; each one scrolls on its own.
        .frame(width: 520, height: 660)
        .tint(Brand.orange)
        .preferredColorScheme(.dark)
    }
}

extension SettingsView {
    /// A small prompt; saving under an existing name updates that preset.
    func askForPresetName() {
        let alert = NSAlert()
        alert.messageText = "Save the current look"
        alert.informativeText = "Backdrop, frame, cursor, camera and export settings are saved together."
        let field = NSTextField(frame: CGRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Preset name"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { preferences.savePreset(named: name) }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let label: (Double) -> String

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double? = nil, label: @escaping (Double) -> String) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.label = label
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                if let step {
                    Slider(value: $value, in: range, step: step)
                } else {
                    Slider(value: $value, in: range)
                }
                Text(label(value)).monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            }
            .frame(width: 230)
        }
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let preferences: Preferences
    private var window: NSWindow?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        DockPresence.windowWillClose(notification)
    }

    private func makeWindow() -> NSWindow {
        let content = NSHostingView(rootView: SettingsView(preferences: preferences))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: content.fittingSize),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Avora Settings"
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}

/// Avora shows a Dock icon only while one of its windows is open.
enum DockPresence {
    @MainActor
    static func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        let othersOpen = NSApp.windows.contains { $0 !== closing && $0.isVisible && $0.canBecomeMain }
        NSApp.setActivationPolicy(othersOpen ? .regular : .accessory)
    }
}

/// Gradient, solid color, a picture of your own or the desktop wallpaper, plus blur.
private struct BackdropSection: View {
    @ObservedObject var preferences: Preferences

    private enum Kind: Hashable { case gradient, color, image, wallpaper }

    private var kind: Kind {
        let id = preferences.backgroundID
        if id.hasPrefix(BackgroundPreset.colorPrefix) { return .color }
        if id.hasPrefix(BackgroundPreset.imagePrefix) { return .image }
        if id == BackgroundPreset.wallpaperID { return .wallpaper }
        return .gradient
    }

    var body: some View {
        Section("Backdrop") {
            Picker("Type", selection: Binding(get: { kind }, set: choose)) {
                Text("Gradient").tag(Kind.gradient)
                Text("Color").tag(Kind.color)
                Text("Image").tag(Kind.image)
                Text("Wallpaper").tag(Kind.wallpaper)
            }
            switch kind {
            case .gradient:
                Text("Pick a gradient in Avora's window or from the Background menu.").font(.caption).foregroundStyle(.secondary)
            case .color:
                ColorPicker("Color", selection: Binding(get: { color }, set: { preferences.backgroundID = Self.id(for: $0) }), supportsOpacity: false)
            case .image:
                LabeledContent("Image") {
                    HStack {
                        Text(preferences.background.name).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                        Button("Choose…") { chooseImage() }
                    }
                }
            case .wallpaper:
                Text("Uses your current desktop picture.").font(.caption).foregroundStyle(.secondary)
            }
            SliderRow("Blur", value: $preferences.settings.backgroundBlur, in: 0...1) { "\(Int(($0 * 100).rounded()))%" }
        }
    }

    private var color: Color {
        if case let .solid(rgb) = preferences.background.fill { return Color(rgb: rgb.hex) }
        return Color(rgb: 0x121318)
    }

    private func choose(_ kind: Kind) {
        switch kind {
        case .gradient: preferences.backgroundID = BackgroundPreset.defaultID
        case .color: preferences.backgroundID = BackgroundPreset.colorPrefix + "121318"
        case .image: chooseImage()
        case .wallpaper: preferences.backgroundID = BackgroundPreset.wallpaperID
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.message = "Pick a picture for the backdrop. Avora fills the frame with it."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        preferences.backgroundID = BackgroundPreset.imagePrefix + url.path
    }

    private static func id(for color: Color) -> String {
        let rgb = NSColor(color).usingColorSpace(.sRGB) ?? .black
        let hex = (Int(rgb.redComponent * 255) << 16) | (Int(rgb.greenComponent * 255) << 8) | Int(rgb.blueComponent * 255)
        return BackgroundPreset.colorPrefix + String(format: "%06X", hex)
    }
}

/// Which camera to record and how its bubble looks in the video.
private struct CameraSection: View {
    @ObservedObject var preferences: Preferences
    @State private var cameras = CameraRecorder.devices

    private var look: Binding<CameraLook> { $preferences.settings.camera }

    var body: some View {
        Section("Camera") {
            Picker("Camera", selection: $preferences.cameraID) {
                Text("Off").tag(String?.none)
                ForEach(cameras, id: \.uniqueID) { Text($0.localizedName).tag(String?.some($0.uniqueID)) }
            }
            if preferences.cameraID != nil {
                Toggle("Show a preview while recording", isOn: $preferences.showsCameraPreview)
                Picker("Position", selection: look.position) {
                    Text("Bottom right").tag(CameraLook.Position.bottomRight)
                    Text("Bottom left").tag(CameraLook.Position.bottomLeft)
                    Text("Bottom").tag(CameraLook.Position.bottom)
                    Text("Top right").tag(CameraLook.Position.topRight)
                    Text("Top left").tag(CameraLook.Position.topLeft)
                    Text("Top").tag(CameraLook.Position.top)
                    Text("Left").tag(CameraLook.Position.left)
                    Text("Right").tag(CameraLook.Position.right)
                }
                Picker("Shape", selection: look.aspect) {
                    Text("Square").tag(CameraLook.Aspect.square)
                    Text("16:9").tag(CameraLook.Aspect.wide)
                    Text("4:3").tag(CameraLook.Aspect.classic)
                    Text("3:4").tag(CameraLook.Aspect.portrait)
                    Text("9:16").tag(CameraLook.Aspect.tall)
                }
                SliderRow("Size", value: look.size, in: 0.15...0.6) { "\(Int(($0 * 100).rounded()))%" }
                SliderRow("Roundness", value: look.roundness, in: 0...0.5) { $0 >= 0.5 ? "Round" : "\(Int(($0 * 200).rounded()))%" }
                Toggle("Mirror", isOn: look.mirrored)
                Toggle("Shrink during zooms", isOn: look.shrinksOnZoom)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in cameras = CameraRecorder.devices }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in cameras = CameraRecorder.devices }
    }
}

/// Captions are written on this Mac from what was said.
private struct CaptionSection: View {
    @ObservedObject var preferences: Preferences
    private let languages = SFSpeechRecognizer.supportedLocales()
        .map { ($0.identifier, Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier) }
        .sorted { $0.1 < $1.1 }

    var body: some View {
        Section("Captions") {
            Toggle("Burn captions into the video", isOn: $preferences.settings.burnsCaptions)
            Toggle("Save captions as an .srt file", isOn: $preferences.settings.savesSubtitles)
            Picker("Language", selection: $preferences.settings.captionLanguage) {
                Text("Same as this Mac").tag("")
                ForEach(languages, id: \.0) { Text($0.1).tag($0.0) }
            }
            Text("Captions are made on export when either is on. Edit Last Recording lets you fix their words first.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
