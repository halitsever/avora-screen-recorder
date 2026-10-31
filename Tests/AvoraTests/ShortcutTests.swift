import Carbon.HIToolbox
import Testing
@testable import Avora

struct ShortcutTests {
    @Test func recordShortcutReadsInMacOrder() {
        #expect(Shortcut.toggleRecording.display == "⌃⌥⌘R")
    }

    @Test func recordShortcutRegistersControlOptionCommandR() {
        let shortcut = Shortcut.toggleRecording
        #expect(shortcut.keyCode == UInt32(kVK_ANSI_R))
        #expect(shortcut.carbonModifiers == UInt32(controlKey | optionKey | cmdKey))
    }

    @Test func pauseShortcutSitsNextToRecord() {
        #expect(Shortcut.togglePause.display == "⌃⌥⌘P")
        #expect(Shortcut.togglePause.carbonModifiers == Shortcut.toggleRecording.carbonModifiers)
    }

    @Test func restartUsesDeleteWithTheSameModifiers() {
        #expect(Shortcut.restart.display == "⌃⌥⌘⌫")
        #expect(Shortcut.restart.keyCode == UInt32(kVK_Delete))
        #expect(Shortcut.restart.menuKey == "\u{8}")
    }

    @Test func menuShowsTheSameModifiers() {
        #expect(Shortcut.toggleRecording.modifiers == [.control, .option, .command])
        #expect(Shortcut.toggleRecording.key == "r")
    }
}
