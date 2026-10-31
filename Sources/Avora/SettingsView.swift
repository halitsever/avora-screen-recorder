import AVFoundation
import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences

    private var settings: Binding<RenderSettings> { $preferences.settings }
    private var format: RenderSettings.Format { preferences.settings.format }
    @State private var microphones = MicrophoneRecorder.devices

    var body: some View {
        Form {
            Section("Audio") {
                Picker("Microphone", selection: $preferences.microphoneID) {
                    Text("Off").tag(String?.none)
                    ForEach(microphones, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(String?.some(device.uniqueID))
                    }
                }
                Toggle("Record system audio", isOn: $preferences.recordsSystemAudio)
                if preferences.microphoneID != nil {
                    Text("Your voice is evened out to a steady level when the video is exported.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Editor") {
                Toggle("Open the editor after each recording", isOn: $preferences.opensEditorAfterRecording)
                Text("The video is saved either way. Edit Last Recording in the menu opens it any time within 7 days.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Video") {
                Picker("Format", selection: settings.format) {
                    Text("MP4 (H.264)").tag(RenderSettings.Format.h264)
                    Text("MP4 (HEVC)").tag(RenderSettings.Format.hevc)
                    Text("ProRes 422 HQ").tag(RenderSettings.Format.prores)
                    Text("GIF").tag(RenderSettings.Format.gif)
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

            Section("Camera") {
                SliderRow("Zoom", value: settings.zoom, in: 1.25...3, step: 0.25) { String(format: "%g×", $0) }
                SliderRow("Motion blur", value: settings.motionBlur, in: 0...1) { "\(Int(($0 * 100).rounded()))%" }
            }

            Section("Frame") {
                SliderRow("Padding", value: settings.padding, in: 0...0.25) { "\(Int(($0 * 100).rounded()))%" }
                SliderRow("Corners", value: settings.cornerRadius, in: 0...0.03) { "\(Int(($0 / 0.03 * 100).rounded()))%" }
                SliderRow("Shadow", value: settings.shadow, in: 0...0.6) { "\(Int(($0 / 0.6 * 100).rounded()))%" }
            }

            Section("Cursor") {
                SliderRow("Size", value: settings.cursorScale, in: 1...3, step: 0.25) { String(format: "%g×", $0) }
                Picker("Smoothing", selection: settings.smoothing) {
                    Text("Smooth").tag(RenderSettings.Smoothing.smooth)
                    Text("Medium").tag(RenderSettings.Smoothing.medium)
                    Text("Rapid").tag(RenderSettings.Smoothing.rapid)
                    Text("Off").tag(RenderSettings.Smoothing.none)
                }
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
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in
            microphones = MicrophoneRecorder.devices
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in
            microphones = MicrophoneRecorder.devices
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .tint(Brand.orange)
        .preferredColorScheme(.dark)
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
