import AppKit
import SwiftUI

/// One editor window per recording; opening the same recording again brings its window forward.
@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    private var windows: [URL: (window: NSWindow, model: EditorModel, keys: Any?)] = [:]
    var onError: ((Error) -> Void)?

    func open(_ folder: RecordingFolder) {
        if let open = windows[folder.url] {
            show(open.window)
            return
        }
        do {
            let model = try EditorModel(folder: folder)
            // The editor fills the screen it opens on; the green button still takes it full screen.
            let screen = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
            let window = NSWindow(contentRect: screen, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Avora Editor"
            window.subtitle = folder.url.lastPathComponent
            window.appearance = NSAppearance(named: .darkAqua)
            window.titlebarAppearsTransparent = true
            window.backgroundColor = Palette.backgroundColor
            window.collectionBehavior.insert(.fullScreenPrimary)
            window.minSize = CGSize(width: 1100, height: 700)
            window.contentView = NSHostingView(rootView: EditorView(model: model))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setFrame(screen, display: false)
            windows[folder.url] = (window, model, keyMonitor(for: window, model: model))
            show(window)
            Task { await model.load() }
        } catch {
            onError?(error)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let entry = windows.first(where: { $0.value.window === window })
        else { return }
        entry.value.model.close()
        if let keys = entry.value.keys { NSEvent.removeMonitor(keys) }
        windows[entry.key] = nil
        DockPresence.windowWillClose(notification)
    }

    private func show(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Editor shortcuts, active only while this window is in front.
    private func keyMonitor(for window: NSWindow, model: EditorModel) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window] event in
            guard event.window === window else { return event }
            // Typing into a caption keeps its spaces and backspaces.
            if window?.firstResponder is NSTextView { return event }
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if modifiers.contains(.command) {
                switch (event.charactersIgnoringModifiers?.lowercased(), modifiers) {
                case ("z", [.command]): model.undo()
                case ("z", [.command, .shift]): model.redo()
                case ("c", [.command]): Task { await model.copyFrame() }
                case ("=", [.command]), ("+", [.command]), ("=", [.command, .shift]), ("+", [.command, .shift]):
                    model.viewport.zoom(by: 1.6, around: model.time)
                case ("-", [.command]): model.viewport.zoom(by: 1 / 1.6, around: model.time)
                case ("0", [.command]): model.viewport.fit()
                default: return event
                }
                return nil
            }
            guard modifiers.subtracting(.shift).isEmpty else { return event }
            let stride = modifiers.contains(.shift) ? 1.0 : 0.1
            switch event.keyCode {
            case 49:
                model.togglePlay()
            case 51, 117:
                model.removeSelected()
            case 53:
                model.selection = nil
            case 1:
                model.splitAtPlayhead()
            case 6:
                if !model.addAtPlayhead(in: .zooms) { NSSound.beep() }
            case 123:
                model.step(by: -stride)
            case 124:
                model.step(by: stride)
            case 115:
                model.seek(to: 0)
            case 119:
                model.seek(to: model.duration)
            default:
                guard let digit = event.charactersIgnoringModifiers.flatMap(Int.init), (1...9).contains(digit) else { return event }
                model.setLevel(1 + Double(digit - 1) * 0.2)
            }
            return nil
        }
    }
}
