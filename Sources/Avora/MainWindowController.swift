import AppKit
import SwiftUI

/// Avora's own window. While it is open the app shows up in the Dock; closing it returns
/// Avora to a menu bar only app.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private let controller: RecordingController
    private let preferences: Preferences
    private let openVideos: () -> Void
    private var window: NSWindow?

    init(controller: RecordingController, preferences: Preferences, openVideos: @escaping () -> Void) {
        self.controller = controller
        self.preferences = preferences
        self.openVideos = openVideos
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 640, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Avora"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = Brand.inkColor
        window.appearance = NSAppearance(named: .darkAqua)

        // The titlebar height differs between macOS releases, so measure it instead of assuming.
        let titlebarHeight = window.frame.height - window.contentLayoutRect.height
        let content = NSHostingView(rootView: MainView(
            controller: controller, preferences: preferences, openVideos: openVideos, titlebarHeight: titlebarHeight
        ))
        // MainView reserves the titlebar space itself; a safe area here would add it a second time.
        content.safeAreaRegions = []
        window.contentView = content
        window.setContentSize(content.fittingSize)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
