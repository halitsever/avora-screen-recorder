import Foundation
import Testing
@testable import Avora

private func freshDefaults() -> UserDefaults {
    let name = "avora.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

struct PreferencesTests {
    @Test func startsWithDefaultBackground() {
        #expect(Preferences(defaults: freshDefaults()).background.id == "avora")
    }

    @Test func rememberedBackgroundSurvivesRelaunch() {
        let defaults = freshDefaults()
        Preferences(defaults: defaults).backgroundID = "sky"
        #expect(Preferences(defaults: defaults).background.id == "sky")
    }

    @Test func staleStoredIDFallsBackToDefault() {
        let defaults = freshDefaults()
        defaults.set("removed-preset", forKey: Preferences.backgroundKey)
        #expect(Preferences(defaults: defaults).background.id == "avora")
    }

    @Test func editorOpensAfterRecordingUntilTurnedOff() {
        let defaults = freshDefaults()
        #expect(Preferences(defaults: defaults).opensEditorAfterRecording)
        Preferences(defaults: defaults).opensEditorAfterRecording = false
        #expect(!Preferences(defaults: defaults).opensEditorAfterRecording)
    }
}
