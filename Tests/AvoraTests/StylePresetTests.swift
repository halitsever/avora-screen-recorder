import Foundation
import Testing
@testable import Avora

private func freshPreferences() -> (Preferences, UserDefaults) {
    let name = "avora.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (Preferences(defaults: defaults), defaults)
}

struct StylePresetTests {
    @Test func savedPresetBringsTheLookBack() {
        let (preferences, _) = freshPreferences()
        preferences.backgroundID = "sky"
        preferences.settings.padding = 0.12
        preferences.settings.clickEffect = .ripple
        preferences.savePreset(named: "Tutorial")

        preferences.backgroundID = "ember"
        preferences.settings = RenderSettings()
        preferences.apply(preferences.presets[0])
        #expect(preferences.backgroundID == "sky")
        #expect(preferences.settings.padding == 0.12)
        #expect(preferences.settings.clickEffect == .ripple)
    }

    @Test func presetsSurviveRelaunch() {
        let (preferences, defaults) = freshPreferences()
        preferences.savePreset(named: "Launch video")
        #expect(Preferences(defaults: defaults).presets.map(\.name) == ["Launch video"])
    }

    @Test func savingUnderAnExistingNameReplacesIt() {
        let (preferences, _) = freshPreferences()
        preferences.savePreset(named: "Demo")
        preferences.settings.zoom = 3
        preferences.savePreset(named: "Demo")
        #expect(preferences.presets.count == 1)
        #expect(preferences.presets[0].settings.zoom == 3)
    }

    @Test func deletingRemovesOnlyThatPreset() {
        let (preferences, _) = freshPreferences()
        preferences.savePreset(named: "A")
        preferences.savePreset(named: "B")
        preferences.deletePreset(preferences.presets[0])
        #expect(preferences.presets.map(\.name) == ["B"])
    }
}
