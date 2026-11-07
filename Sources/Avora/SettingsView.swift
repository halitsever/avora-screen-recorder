import AVFoundation
import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences

    private var settings: Binding<RenderSettings> { $preferences.settings }
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
                MotionSection(settings: settings)
                FrameSection(settings: settings)
                CursorSection(settings: settings)
            }
            .formStyle(.grouped)
            .tabItem { Label("Look", systemImage: "paintpalette") }

            Form {
                VideoSection(settings: settings)
                PresetsSection(preferences: preferences)
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
        .tint(Palette.tint)
        .preferredColorScheme(.dark)
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

/// Which camera to record and how its bubble looks in the video.
private struct CameraSection: View {
    @ObservedObject var preferences: Preferences
    @State private var cameras = CameraRecorder.devices

    var body: some View {
        Section("Camera") {
            Picker("Camera", selection: $preferences.cameraID) {
                Text("Off").tag(String?.none)
                ForEach(cameras, id: \.uniqueID) { Text($0.localizedName).tag(String?.some($0.uniqueID)) }
            }
            if preferences.cameraID != nil {
                Toggle("Show a preview while recording", isOn: $preferences.showsCameraPreview)
                CameraLookRows(look: $preferences.settings.camera)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in cameras = CameraRecorder.devices }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in cameras = CameraRecorder.devices }
    }
}
