import AppKit
import Speech
import SwiftUI

// Form sections shared by the Settings window and the editor's inspector. Both change the same preferences.

struct SliderRow: View {
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
            .frame(minWidth: 140, maxWidth: 230)
        }
    }
}

/// Gradient, solid color, a picture of your own or the desktop wallpaper, plus blur.
struct BackdropSection: View {
    @ObservedObject var preferences: Preferences
    /// Settings sends people to Avora's window for gradients; the editor lists them here.
    var showsGallery = false

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
            if showsGallery {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(BackgroundPreset.all) { preset in
                        Swatch(preset: preset, isSelected: preset.id == preferences.backgroundID, ring: Palette.foreground) {
                            preferences.backgroundID = preset.id
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            Picker("Type", selection: Binding(get: { kind }, set: choose)) {
                Text("Gradient").tag(Kind.gradient)
                Text("Color").tag(Kind.color)
                Text("Image").tag(Kind.image)
                Text("Wallpaper").tag(Kind.wallpaper)
            }
            switch kind {
            case .gradient:
                if !showsGallery {
                    Text("Pick a gradient in Avora's window or from the Background menu.").font(.caption).foregroundStyle(.secondary)
                }
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

struct MotionSection: View {
    @Binding var settings: RenderSettings

    var body: some View {
        Section("Motion") {
            SliderRow("Zoom", value: $settings.zoom, in: 1.25...3, step: 0.25) { String(format: "%g×", $0) }
            SliderRow("Motion blur", value: $settings.motionBlur, in: 0...1) { "\(Int(($0 * 100).rounded()))%" }
        }
    }
}

struct FrameSection: View {
    @Binding var settings: RenderSettings
    var showsShape = false

    var body: some View {
        Section("Frame") {
            if showsShape { ShapePicker(aspect: $settings.aspect) }
            SliderRow("Padding", value: $settings.padding, in: 0...0.25) { "\(Int(($0 * 100).rounded()))%" }
            SliderRow("Corners", value: $settings.cornerRadius, in: 0...0.03) { "\(Int(($0 / 0.03 * 100).rounded()))%" }
            SliderRow("Shadow", value: $settings.shadow, in: 0...0.6) { "\(Int(($0 / 0.6 * 100).rounded()))%" }
        }
    }
}

struct CursorSection: View {
    @Binding var settings: RenderSettings

    var body: some View {
        Section("Cursor") {
            Toggle("Show the cursor", isOn: $settings.showsCursor)
            Picker("Click effect", selection: $settings.clickEffect) {
                Text("None").tag(RenderSettings.ClickEffect.none)
                Text("Circle").tag(RenderSettings.ClickEffect.circle)
                Text("Ripple").tag(RenderSettings.ClickEffect.ripple)
            }
            .disabled(!settings.showsCursor)
            Toggle("Hide after 2 s without moving", isOn: $settings.hidesIdleCursor)
                .disabled(!settings.showsCursor)
            SliderRow("Hold still at the end", value: $settings.cursorFreeze, in: 0...5, step: 0.5) { $0 == 0 ? "Off" : String(format: "%g s", $0) }
            SliderRow("Size", value: $settings.cursorScale, in: 1...3, step: 0.25) { String(format: "%g×", $0) }
            Picker("Smoothing", selection: $settings.smoothing) {
                Text("Smooth").tag(RenderSettings.Smoothing.smooth)
                Text("Medium").tag(RenderSettings.Smoothing.medium)
                Text("Rapid").tag(RenderSettings.Smoothing.rapid)
                Text("Off").tag(RenderSettings.Smoothing.none)
            }
        }
    }
}

struct ShapePicker: View {
    @Binding var aspect: RenderSettings.Aspect

    var body: some View {
        Picker("Shape", selection: $aspect) {
            Text("Same as recording").tag(RenderSettings.Aspect.auto)
            Text("16:9 Widescreen").tag(RenderSettings.Aspect.wide)
            Text("4:3").tag(RenderSettings.Aspect.classic)
            Text("1:1 Square").tag(RenderSettings.Aspect.square)
            Text("4:5 Feed").tag(RenderSettings.Aspect.feed)
            Text("3:4").tag(RenderSettings.Aspect.portrait)
            Text("9:16 Stories and Reels").tag(RenderSettings.Aspect.vertical)
        }
    }
}

struct VideoSection: View {
    @Binding var settings: RenderSettings
    var showsShape = true

    var body: some View {
        Section("Video") {
            Picker("Format", selection: $settings.format) {
                Text("MP4 (H.264)").tag(RenderSettings.Format.h264)
                Text("MP4 (HEVC)").tag(RenderSettings.Format.hevc)
                Text("ProRes 422 HQ").tag(RenderSettings.Format.prores)
                Text("GIF").tag(RenderSettings.Format.gif)
            }
            if showsShape { ShapePicker(aspect: $settings.aspect) }
            Picker("Resolution", selection: $settings.resolution) {
                Text("Same as recording").tag(RenderSettings.Resolution.source)
                Text("4K").tag(RenderSettings.Resolution.uhd)
                Text("1080p").tag(RenderSettings.Resolution.fullHD)
                Text("720p").tag(RenderSettings.Resolution.hd)
            }
            Picker("Frame rate", selection: $settings.fps) {
                Text("60 fps").tag(60)
                Text("30 fps").tag(30)
            }
            .disabled(settings.format == .gif)
            Picker("Quality", selection: $settings.quality) {
                Text("Studio").tag(RenderSettings.Quality.studio)
                Text("Social").tag(RenderSettings.Quality.social)
                Text("Web").tag(RenderSettings.Quality.web)
            }
            .disabled(settings.format == .prores || settings.format == .gif)
            if settings.format == .gif {
                Text("GIFs are 15 fps and at most 960 pixels wide.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PresetsSection: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
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
            Button("Save Current Look…") { askForName() }
        }
    }

    /// Saving under an existing name updates that preset.
    private func askForName() {
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

/// How the camera bubble looks in the video. Rows for a section someone else owns.
struct CameraLookRows: View {
    @Binding var look: CameraLook

    var body: some View {
        Picker("Position", selection: $look.position) {
            Text("Bottom right").tag(CameraLook.Position.bottomRight)
            Text("Bottom left").tag(CameraLook.Position.bottomLeft)
            Text("Bottom").tag(CameraLook.Position.bottom)
            Text("Top right").tag(CameraLook.Position.topRight)
            Text("Top left").tag(CameraLook.Position.topLeft)
            Text("Top").tag(CameraLook.Position.top)
            Text("Left").tag(CameraLook.Position.left)
            Text("Right").tag(CameraLook.Position.right)
        }
        Picker("Shape", selection: $look.aspect) {
            Text("Square").tag(CameraLook.Aspect.square)
            Text("16:9").tag(CameraLook.Aspect.wide)
            Text("4:3").tag(CameraLook.Aspect.classic)
            Text("3:4").tag(CameraLook.Aspect.portrait)
            Text("9:16").tag(CameraLook.Aspect.tall)
        }
        SliderRow("Size", value: $look.size, in: 0.15...0.6) { "\(Int(($0 * 100).rounded()))%" }
        SliderRow("Roundness", value: $look.roundness, in: 0...0.5) { $0 >= 0.5 ? "Round" : "\(Int(($0 * 200).rounded()))%" }
        Toggle("Mirror", isOn: $look.mirrored)
        Toggle("Shrink during zooms", isOn: $look.shrinksOnZoom)
    }
}

/// Captions are written on this Mac from what was said.
struct CaptionSection: View {
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
