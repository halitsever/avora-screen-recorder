import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = RecordingController()
    private let preferences = Preferences.shared
    private lazy var mainWindow = MainWindowController(
        controller: controller, preferences: preferences,
        openVideos: { [weak self] in self?.openVideos() },
        openSettings: { [weak self] in self?.settingsWindow.show() }
    )
    private lazy var settingsWindow = SettingsWindowController(preferences: preferences)
    private let editor = EditorWindowController()
    private var statusItem: NSStatusItem!
    private var clock: Timer?
    private var hotKeys: [GlobalHotKey] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Brand.registerFonts()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        controller.onChange = { [weak self] in self?.refreshButton() }
        controller.onError = { [weak self] in self?.show($0) }
        controller.onFinished = { [weak self] folder in
            guard let self, preferences.opensEditorAfterRecording else { return }
            editor.open(folder)
        }
        editor.onError = { [weak self] in self?.show($0) }
        refreshButton()
        register(.toggleRecording) { [weak self] in self?.toggleRecording() }
        register(.togglePause) { [weak self] in self?.togglePause() }
        register(.restart) { [weak self] in self?.restartRecording() }
        Task.detached(priority: .utility) { RawRecordings.removeExpired() }
        mainWindow.show()
        offerRecovery()
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
            menu.addItem(recordItem(Self.startTitle(for: preferences.captureMode)))
        case .starting:
            menu.addItem(NSMenuItem(title: "Starting…", action: nil, keyEquivalent: ""))
        case .recording(let timer):
            menu.addItem(recordItem("Stop Recording"))
            menu.addItem(shortcutItem(timer.isPaused ? "Resume Recording" : "Pause Recording", #selector(togglePause), .togglePause))
            menu.addItem(shortcutItem("Restart Recording", #selector(restartRecording), .restart))
            menu.addItem(item("Discard Recording…", #selector(discardRecording), key: ""))
        case .rendering(let progress):
            menu.addItem(NSMenuItem(title: "Rendering video… \(Int(progress * 100))%", action: nil, keyEquivalent: ""))
        }

        menu.addItem(.separator())
        let capture = NSMenuItem(title: "Capture", action: nil, keyEquivalent: "")
        capture.submenu = captureMenu()
        menu.addItem(capture)
        let backgrounds = NSMenuItem(title: "Background", action: nil, keyEquivalent: "")
        backgrounds.submenu = backgroundMenu()
        menu.addItem(backgrounds)
        menu.addItem(item("Open Avora…", #selector(openWindow), key: ""))
        let edit = item("Edit Last Recording…", #selector(editLastRecording), key: "e")
        if controller.state != .idle || RawRecordings.latest() == nil { edit.action = nil }
        menu.addItem(edit)
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("Open Videos Folder", #selector(openVideosFromMenu), key: ""))
        menu.addItem(clearItem())
        menu.addItem(.separator())
        menu.addItem(item("Quit Avora", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    private static func startTitle(for mode: CaptureMode) -> String {
        switch mode {
        case .screen: "Record Screen"
        case .window: "Record Window…"
        case .area: "Record Area…"
        }
    }

    private func captureMenu() -> NSMenu {
        let menu = NSMenu()
        let entries: [(CaptureMode, String, String)] = [
            (.screen, "Whole Screen", "display"), (.window, "Window", "macwindow"), (.area, "Area", "rectangle.dashed"),
        ]
        for (mode, title, symbolName) in entries {
            let entry = item(title, #selector(chooseCaptureMode(_:)), key: "")
            entry.representedObject = mode.rawValue
            entry.state = mode == preferences.captureMode ? .on : .off
            entry.image = symbol(symbolName)
            menu.addItem(entry)
        }
        return menu
    }

    @objc private func chooseCaptureMode(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = CaptureMode(rawValue: raw) { preferences.captureMode = mode }
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

    /// The key equivalent only labels the item; the global hot key does the work from any app.
    private func recordItem(_ title: String) -> NSMenuItem {
        shortcutItem(title, #selector(toggleRecording), .toggleRecording)
    }

    private func shortcutItem(_ title: String, _ action: Selector, _ shortcut: Shortcut) -> NSMenuItem {
        let entry = item(title, action, key: shortcut.menuKey ?? shortcut.key)
        entry.keyEquivalentModifierMask = shortcut.modifiers
        return entry
    }

    private func register(_ shortcut: Shortcut, _ action: @escaping @MainActor () -> Void) {
        if let hotKey = GlobalHotKey(shortcut, action: { MainActor.assumeIsolated(action) }) {
            hotKeys.append(hotKey)
        } else {
            NSLog("Avora: could not register \(shortcut.display), another app may own it")
        }
    }

    private func clearItem() -> NSMenuItem {
        let size = RawRecordings.size()
        let label = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        let entry = item(size > 0 ? "Clear Raw Recordings (\(label))…" : "Clear Raw Recordings", #selector(clearRawRecordings), key: "")
        // A raw recording in progress must not disappear under the recorder.
        if size == 0 || controller.state != .idle { entry.action = nil }
        return entry
    }

    private func refreshButton() {
        let button = statusItem.button
        switch controller.state {
        case .idle, .starting:
            button?.image = brandIcon()
            button?.title = ""
        case .recording(let timer):
            button?.image = symbol(timer.isPaused ? "pause.circle.fill" : "stop.circle.fill")
            button?.title = " " + elapsed(timer)
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

    @objc private func togglePause() {
        controller.togglePause()
    }

    @objc private func restartRecording() {
        Task { await controller.discard(restart: true) }
    }

    @objc private func discardRecording() {
        let alert = NSAlert()
        alert.messageText = "Discard this recording?"
        alert.informativeText = "Nothing from it is saved."
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Keep Recording")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await controller.discard(restart: false) }
    }

    /// A recording that was cut short by a crash is offered back once, at launch.
    private func offerRecovery() {
        guard let folder = RawRecordings.unfinished().last else { return }
        let alert = NSAlert()
        alert.messageText = "Recover the unfinished recording?"
        alert.informativeText = "Avora stopped while recording \(folder.url.lastPathComponent). What was saved up to then can still become a video."
        alert.addButton(withTitle: "Recover")
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: Task { await controller.recover(folder) }
        case .alertSecondButtonReturn: try? FileManager.default.removeItem(at: folder.url)
        default: break
        }
    }

    @objc private func clearRawRecordings() {
        let alert = NSAlert()
        alert.messageText = "Clear raw recordings?"
        alert.informativeText = "Finished videos in Movies stay. You won't be able to render these recordings again with another background."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn, controller.state == .idle else { return }
        RawRecordings.removeAll()
    }

    @objc private func chooseBackground(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { preferences.backgroundID = id }
    }

    @objc private func openWindow() {
        mainWindow.show()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func editLastRecording() {
        if let folder = RawRecordings.latest() { editor.open(folder) }
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

    private func elapsed(_ timer: RecordingTimer) -> String {
        let seconds = Int(timer.elapsed())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
