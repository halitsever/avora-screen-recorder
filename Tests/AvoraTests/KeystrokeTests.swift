import AppKit
import Carbon.HIToolbox
import Testing
@testable import Avora

struct KeystrokeTests {
    @Test func shortcutsReadInMacOrder() {
        #expect(KeyLabel.make(keyCode: UInt16(kVK_ANSI_K), characters: "k", modifiers: [.command, .shift]) == "⇧⌘K")
        #expect(KeyLabel.make(keyCode: UInt16(kVK_Return), characters: "\r", modifiers: [.command]) == "⌘↩")
        #expect(KeyLabel.make(keyCode: UInt16(kVK_LeftArrow), characters: "", modifiers: [.option]) == "⌥←")
    }

    @Test func plainTypingIsNeverRecorded() {
        #expect(KeyLabel.make(keyCode: UInt16(kVK_ANSI_A), characters: "a", modifiers: []) == nil)
        #expect(KeyLabel.make(keyCode: UInt16(kVK_ANSI_A), characters: "A", modifiers: [.shift]) == nil)
    }

    @Test func badgeShowsTheLatestPressThenFades() {
        let presses = [KeyPress(time: 1, label: "⌘C"), KeyPress(time: 2, label: "⌘V")]
        #expect(KeystrokeOverlay.visible(at: 0.5, in: presses) == nil)
        #expect(KeystrokeOverlay.visible(at: 1.5, in: presses)?.label == "⌘C")
        #expect(KeystrokeOverlay.visible(at: 2.1, in: presses)?.label == "⌘V")
        let fading = KeystrokeOverlay.visible(at: 2 + KeystrokeOverlay.hold + KeystrokeOverlay.fade / 2, in: presses)?.opacity ?? 0
        #expect(abs(fading - 0.5) < 1e-9)
        #expect(KeystrokeOverlay.visible(at: 5, in: presses) == nil)
    }
}
