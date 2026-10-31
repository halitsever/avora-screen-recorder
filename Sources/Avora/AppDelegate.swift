import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = RecordingController()
    private let preferences = Preferences.shared
    private lazy var mainWindow = MainWindowController(
        controller: controller, preferences: preferences, openVideos: { [weak self] in self?.openVideos() }
    )
    private var statusItem: NSStatusItem!
    private var clock: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Brand.registerFonts()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        controller.onChange = { [weak self] in self?.refreshButton() }
        controller.onError = { [weak self] in self?.show($0) }
        refreshButton()
        mainWindow.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        mainWindow.show()
        return false
    }

    /// Rebuilt on every open so the checkmarks and labels always match the current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        switch controller.state {
        case .idle:
            menu.addItem(item("Start Recording", #selector(toggleRecording), key: "r"))
        case .starting:
            menu.addItem(NSMenuItem(title: "Starting…", action: nil, keyEquivalent: ""))
        case .recording:
            menu.addItem(item("Stop Recording", #selector(toggleRecording), key: "r"))
        case .rendering(let progress):
            menu.addItem(NSMenuItem(title: "Rendering video… \(Int(progress * 100))%", action: nil, keyEquivalent: ""))
        }

        menu.addItem(.separator())
        let backgrounds = NSMenuItem(title: "Background", action: nil, keyEquivalent: "")
        backgrounds.submenu = backgroundMenu()
        menu.addItem(backgrounds)
        menu.addItem(item("Open Avora…", #selector(openWindow), key: ""))
        menu.addItem(item("Open Videos Folder", #selector(openVideosFromMenu), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("Quit Avora", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    private func backgroundMenu() -> NSMenu {
        let menu = NSMenu()
        for preset in BackgroundPreset.all {
            let entry = item(preset.name, #selector(chooseBackground(_:)), key: "")
            entry.representedObject = preset.id
            entry.state = preset.id == preferences.backgroundID ? .on : .off
            entry.image = BackgroundThumbnails.image(for: preset, size: CGSize(width: 22, height: 14))
            menu.addItem(entry)
        }
        return menu
    }

    private func refreshButton() {
        let button = statusItem.button
        switch controller.state {
        case .idle, .starting:
            button?.image = brandIcon()
            button?.title = ""
        case .recording(let since):
            button?.image = symbol("stop.circle.fill")
            button?.title = " " + elapsed(since)
        case .rendering(let progress):
            button?.image = brandIcon()
            button?.title = " \(Int(progress * 100))%"
        }

        if case .recording = controller.state {
            if clock == nil {
                clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refreshButton() }
                }
            }
        } else {
            clock?.invalidate()
            clock = nil
        }
    }

    @objc private func toggleRecording() {
        Task { await controller.toggle() }
    }

    @objc private func chooseBackground(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { preferences.backgroundID = id }
    }

    @objc private func openWindow() {
        mainWindow.show()
    }

    @objc private func openVideosFromMenu() {
        openVideos()
    }

    private func openVideos() {
        if let url = try? RecordingFolder.newMovieURL().deletingLastPathComponent() {
            NSWorkspace.shared.open(url)
        }
    }

    private func show(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Avora"
        alert.informativeText = error.localizedDescription
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func item(_ title: String, _ action: Selector, key: String, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        return item
    }

    private func brandIcon() -> NSImage? {
        NSImage(named: "avoraTemplate") ?? symbol("record.circle")
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Avora")
        image?.isTemplate = true
        return image
    }

    private func elapsed(_ since: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(since))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
