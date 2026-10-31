import Foundation
import Testing
import ZoomEngine
@testable import Avora

struct RenderSettingsTests {
    private let source = CGSize(width: 3456, height: 2234)

    @Test func defaultsMatchTheOriginalLook() {
        let style = OutputStyle(settings: RenderSettings(), background: .named(nil))
        #expect(style.fps == 60)
        #expect(style.padding == 0.06)
        #expect(style.zoomScale == 2)
        #expect(style.motionBlur == 1)
        #expect(style.cursorSpring == .cursor)
    }

    @Test func storedSettingsWithMissingKeysFallBackToDefaults() throws {
        let decoded = try JSONDecoder().decode(RenderSettings.self, from: Data(#"{"zoom": 2.5, "format": "hevc"}"#.utf8))
        #expect(decoded.zoom == 2.5)
        #expect(decoded.format == .hevc)
        #expect(decoded.padding == RenderSettings().padding)
        #expect(decoded.smoothing == .smooth)
    }

    @Test func unknownStoredValuesFallBackToDefaults() throws {
        let decoded = try JSONDecoder().decode(RenderSettings.self, from: Data(#"{"format": "webm", "fps": 60}"#.utf8))
        #expect(decoded.format == .h264)
    }

    @Test func sourceResolutionKeepsTheRecordingSizeUpTo4KWide() {
        #expect(RenderSettings.Resolution.source.canvasSize(for: source) == source)
        #expect(RenderSettings.Resolution.source.canvasSize(for: CGSize(width: 5120, height: 2880)) == CGSize(width: 3840, height: 2160))
    }

    @Test func presetResolutionsSetTheHeight() {
        #expect(RenderSettings.Resolution.fullHD.canvasSize(for: source) == CGSize(width: 1670, height: 1080))
        #expect(RenderSettings.Resolution.hd.canvasSize(for: source).height == 720)
    }

    @Test func gifIsSmallAndSlow() {
        var settings = RenderSettings()
        settings.format = .gif
        let style = OutputStyle(settings: settings, background: .named(nil))
        #expect(style.fps == 15)
        #expect(style.canvasSize(for: source).width <= 960)
    }

    @Test func qualityScalesTheBitrate() {
        let size = CGSize(width: 1920, height: 1080)
        let studio = RenderSettings.bitrate(for: size, fps: 60, format: .h264, quality: .studio)
        let social = RenderSettings.bitrate(for: size, fps: 60, format: .h264, quality: .social)
        let web = RenderSettings.bitrate(for: size, fps: 60, format: .h264, quality: .web)
        #expect(studio > social && social > web)
        #expect(RenderSettings.bitrate(for: size, fps: 60, format: .hevc, quality: .social) < social)
    }

    @Test func smoothingPresetsPickCursorSprings() {
        #expect(RenderSettings.Smoothing.smooth.spring == .cursor)
        #expect(RenderSettings.Smoothing.rapid.spring == SpringConfig(mass: 1, stiffness: 530, damping: 40))
        #expect(RenderSettings.Smoothing.none.spring == nil)
    }

    @Test func settingsSurviveRelaunch() {
        let name = "avora.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        Preferences(defaults: defaults).settings.motionBlur = 0.25
        #expect(Preferences(defaults: defaults).settings.motionBlur == 0.25)
    }
}
