import AppKit
import Carbon.HIToolbox
import CoreImage

/// One keyboard shortcut pressed while recording; `time` is in the recording.
struct KeyPress: Codable, Equatable {
    var time: Double
    var label: String
}

enum KeyLabel {
    private static let names: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    /// A shortcut as macOS writes it, or nil for plain typing, which is never recorded.
    static func make(keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags) -> String? {
        guard !modifiers.intersection([.command, .control, .option]).isEmpty else { return nil }
        let key = names[Int(keyCode)] ?? characters.uppercased()
        guard !key.isEmpty else { return nil }
        let symbols: [(NSEvent.ModifierFlags, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + key
    }
}

/// Listens for shortcuts anywhere on the Mac while recording. macOS only delivers them once
/// Avora is allowed under Accessibility.
final class KeystrokeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let notesTyping: Bool
    private var presses: [(host: Double, label: String)] = []
    private var typing: [Double] = []
    private var monitor: Any?
    /// Avora's own shortcuts start and stop the recording; they don't belong in it.
    private let ignored = Set([Shortcut.toggleRecording, .togglePause, .restart].map(\.display))

    /// With `notesTyping`, the moment of every key press is kept too, but never which key it was.
    init(notesTyping: Bool) {
        self.notesTyping = notesTyping
    }

    /// Asks for Accessibility access the first time; returns whether it is granted.
    @discardableResult
    static func requestAccess() -> Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if notesTyping { lock.withLock { self.typing.append(event.timestamp) } }
            guard let label = KeyLabel.make(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers ?? "", modifiers: event.modifierFlags),
                  !ignored.contains(label)
            else { return }
            // Event timestamps count from boot, like the host clock the capture runs on.
            lock.withLock { self.presses.append((event.timestamp, label)) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// When keys were pressed, outside pauses and counted from the first video frame.
    func typingTimes(clock: RecordingClock, videoStart: Double) -> [Double] {
        lock.withLock { typing }.compactMap { clock.recordingTime(forHost: $0).map { $0 - videoStart } }
    }

    /// Presses outside pauses, with times counted from the first video frame.
    func presses(clock: RecordingClock, videoStart: Double) -> [KeyPress] {
        lock.withLock { presses }.compactMap { press in
            clock.recordingTime(forHost: press.host).map { KeyPress(time: $0 - videoStart, label: press.label) }
        }
    }
}

/// The badge that shows the last shortcut near the bottom of the video.
enum KeystrokeOverlay {
    static let hold = 1.2
    static let fade = 0.3

    static func visible(at time: Double, in presses: [KeyPress]) -> (label: String, opacity: Double)? {
        guard let press = presses.last(where: { $0.time <= time }) else { return nil }
        let age = time - press.time
        guard age <= hold + fade else { return nil }
        return (press.label, age <= hold ? 1 : 1 - (age - hold) / fade)
    }

    /// The badge with its origin at zero, in Core Image space.
    static func badge(_ label: String, canvas: CGSize) -> CIImage {
        let size = canvas.height * 0.036
        let text = NSAttributedString(string: label, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        let glyphs = CIFilter(name: "CIAttributedTextImageGenerator", parameters: ["inputText": text, "inputScaleFactor": 1])?.outputImage ?? .empty()
        let pad = CGSize(width: size * 0.7, height: size * 0.42)
        let pill = CGRect(x: 0, y: 0, width: glyphs.extent.width + pad.width * 2, height: glyphs.extent.height + pad.height * 2)
        let background = CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: pill), "inputRadius": pill.height / 2,
            "inputColor": CIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 0.78),
        ])?.outputImage ?? .empty()
        let placedText = glyphs.transformed(by: CGAffineTransform(translationX: pad.width - glyphs.extent.minX, y: pad.height - glyphs.extent.minY))
        return placedText.composited(over: background)
    }
}
