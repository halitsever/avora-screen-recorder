import AppKit
import Carbon.HIToolbox

struct Shortcut {
    /// What the shortcut shows; also the menu key equivalent unless `menuKey` says otherwise.
    let key: String
    let keyCode: UInt32
    let modifiers: NSEvent.ModifierFlags
    var menuKey: String?

    /// ⌘R alone would steal Reload from every app, so recording uses a combo almost nothing else claims.
    static let toggleRecording = Shortcut(key: "r", keyCode: UInt32(kVK_ANSI_R), modifiers: [.control, .option, .command])
    static let togglePause = Shortcut(key: "p", keyCode: UInt32(kVK_ANSI_P), modifiers: [.control, .option, .command])
    static let restart = Shortcut(key: "⌫", keyCode: UInt32(kVK_Delete), modifiers: [.control, .option, .command], menuKey: "\u{8}")

    var carbonModifiers: UInt32 {
        var flags = 0
        if modifiers.contains(.control) { flags |= controlKey }
        if modifiers.contains(.option) { flags |= optionKey }
        if modifiers.contains(.shift) { flags |= shiftKey }
        if modifiers.contains(.command) { flags |= cmdKey }
        return UInt32(flags)
    }

    var display: String {
        let symbols: [(NSEvent.ModifierFlags, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + key.uppercased()
    }
}

/// A shortcut that works while another app is in front. Carbon hot keys need no Accessibility permission.
final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let id: UInt32
    private let action: () -> Void
    private static var nextID: UInt32 = 1

    init?(_ shortcut: Shortcut, action: @escaping () -> Void) {
        self.action = action
        id = Self.nextID
        Self.nextID += 1
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // Every hot key's handler sees every press, so each one checks the ID it registered.
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var pressedID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &pressedID)
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            guard pressedID.id == hotKey.id else { return OSStatus(eventNotHandledErr) }
            hotKey.action()
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { return nil }

        let id = EventHotKeyID(signature: OSType(0x4156_5241), id: id)
        let registered = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKey)
        guard registered == noErr else {
            RemoveEventHandler(handler)
            return nil
        }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
