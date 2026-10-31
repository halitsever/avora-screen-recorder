import CoreGraphics
import Foundation
import ZoomEngine

/// What the user can change about exported videos. Stored as one JSON value; keys missing from
/// an older copy keep their defaults.
struct RenderSettings: Equatable {
    enum Format: String, Codable, CaseIterable {
        case h264, hevc, prores, gif
    }

    enum Resolution: String, Codable, CaseIterable {
        case source, uhd, fullHD, hd

        /// Output size in pixels, kept even because the video encoders need it.
        func canvasSize(for source: CGSize) -> CGSize {
            let scale: Double = switch self {
            case .source: min(1, 3840 / source.width)
            case .uhd: min(2160 / source.height, 3840 / source.width)
            case .fullHD: 1080 / source.height
            case .hd: 720 / source.height
            }
            return CGSize(width: even(source.width * scale), height: even(source.height * scale))
        }
    }

    /// Shape of the exported video. Auto follows the recording.
    enum Aspect: String, Codable, CaseIterable {
        case auto, wide, square, classic, vertical, portrait, feed

        /// Width over height; nil for auto.
        var ratio: Double? {
            switch self {
            case .auto: nil
            case .wide: 16.0 / 9
            case .square: 1
            case .classic: 4.0 / 3
            case .vertical: 9.0 / 16
            case .portrait: 3.0 / 4
            case .feed: 4.0 / 5
            }
        }
    }

    enum Quality: String, Codable, CaseIterable {
        case studio, social, web
    }

    enum ClickEffect: String, Codable, CaseIterable {
        case none, circle, ripple

        /// How long one click's effect stays on screen.
        var duration: Double {
            switch self {
            case .none: 0
            case .circle: 0.45
            case .ripple: 1.0
            }
        }
    }

    enum Smoothing: String, Codable, CaseIterable {
        case smooth, medium, rapid, none

        var spring: SpringConfig? {
            switch self {
            case .smooth: .cursor
            case .medium: SpringConfig(mass: 3, stiffness: 340, damping: 60)
            case .rapid: SpringConfig(mass: 1, stiffness: 530, damping: 40)
            case .none: nil
            }
        }
    }

    var format = Format.h264
    var resolution = Resolution.source
    var aspect = Aspect.auto
    /// 0 keeps the backdrop sharp; 1 blurs it heavily, for busy pictures.
    var backgroundBlur = 0.0
    var camera = CameraLook()
    var showsShortcuts = false
    /// Notes when keys are pressed, never which, so typing can be sped up in the editor.
    var notesTyping = false
    var voice = VoicePreset.standard
    var burnsCaptions = false
    var savesSubtitles = false
    /// A locale identifier for speech recognition; empty uses the Mac's language.
    var captionLanguage = ""
    var fps = 60
    var quality = Quality.social
    var zoom = 2.0
    var padding = 0.06
    var cornerRadius = 0.012
    var shadow = 0.45
    var cursorScale = 1.5
    var smoothing = Smoothing.smooth
    var motionBlur = 1.0
    var showsCursor = true
    var clickEffect = ClickEffect.none
    var hidesIdleCursor = false
    /// Seconds at the end during which the cursor holds still.
    var cursorFreeze = 0.0

    static let gifFPS = 15.0
    static let gifMaxWidth = 960.0

    /// Bits per second. Social matches the bitrate Avora used before quality became a choice.
    static func bitrate(for size: CGSize, fps: Double, format: Format, quality: Quality) -> Int {
        let bitsPerPixel = switch quality {
        case .studio: 0.16
        case .social: 0.067
        case .web: 0.03
        }
        let efficiency = format == .hevc ? 0.6 : 1
        return Int(size.width * size.height * fps * bitsPerPixel * efficiency)
    }
}

extension RenderSettings: Codable {
    private enum Key: String, CodingKey {
        case format, resolution, fps, quality, zoom, padding, cornerRadius, shadow, cursorScale, smoothing, motionBlur
        case showsCursor, clickEffect, hidesIdleCursor, cursorFreeze, aspect, backgroundBlur, camera, showsShortcuts, notesTyping, voice, burnsCaptions, savesSubtitles, captionLanguage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        func value<T: Decodable>(_ key: Key, _ fallback: T) -> T { ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback }
        let defaults = RenderSettings()
        format = value(.format, defaults.format)
        resolution = value(.resolution, defaults.resolution)
        fps = value(.fps, defaults.fps)
        quality = value(.quality, defaults.quality)
        zoom = value(.zoom, defaults.zoom)
        padding = value(.padding, defaults.padding)
        cornerRadius = value(.cornerRadius, defaults.cornerRadius)
        shadow = value(.shadow, defaults.shadow)
        cursorScale = value(.cursorScale, defaults.cursorScale)
        smoothing = value(.smoothing, defaults.smoothing)
        motionBlur = value(.motionBlur, defaults.motionBlur)
        showsCursor = value(.showsCursor, defaults.showsCursor)
        clickEffect = value(.clickEffect, defaults.clickEffect)
        hidesIdleCursor = value(.hidesIdleCursor, defaults.hidesIdleCursor)
        cursorFreeze = value(.cursorFreeze, defaults.cursorFreeze)
        aspect = value(.aspect, defaults.aspect)
        backgroundBlur = value(.backgroundBlur, defaults.backgroundBlur)
        camera = value(.camera, defaults.camera)
        showsShortcuts = value(.showsShortcuts, defaults.showsShortcuts)
        notesTyping = value(.notesTyping, defaults.notesTyping)
        voice = value(.voice, defaults.voice)
        burnsCaptions = value(.burnsCaptions, defaults.burnsCaptions)
        savesSubtitles = value(.savesSubtitles, defaults.savesSubtitles)
        captionLanguage = value(.captionLanguage, defaults.captionLanguage)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(format, forKey: .format)
        try c.encode(resolution, forKey: .resolution)
        try c.encode(fps, forKey: .fps)
        try c.encode(quality, forKey: .quality)
        try c.encode(zoom, forKey: .zoom)
        try c.encode(padding, forKey: .padding)
        try c.encode(cornerRadius, forKey: .cornerRadius)
        try c.encode(shadow, forKey: .shadow)
        try c.encode(cursorScale, forKey: .cursorScale)
        try c.encode(smoothing, forKey: .smoothing)
        try c.encode(motionBlur, forKey: .motionBlur)
        try c.encode(showsCursor, forKey: .showsCursor)
        try c.encode(clickEffect, forKey: .clickEffect)
        try c.encode(hidesIdleCursor, forKey: .hidesIdleCursor)
        try c.encode(cursorFreeze, forKey: .cursorFreeze)
        try c.encode(aspect, forKey: .aspect)
        try c.encode(backgroundBlur, forKey: .backgroundBlur)
        try c.encode(camera, forKey: .camera)
        try c.encode(showsShortcuts, forKey: .showsShortcuts)
        try c.encode(notesTyping, forKey: .notesTyping)
        try c.encode(voice, forKey: .voice)
        try c.encode(burnsCaptions, forKey: .burnsCaptions)
        try c.encode(savesSubtitles, forKey: .savesSubtitles)
        try c.encode(captionLanguage, forKey: .captionLanguage)
    }
}

private func even(_ value: Double) -> Double { (value / 2).rounded() * 2 }

extension RenderSettings {
    var captionLocale: Locale { captionLanguage.isEmpty ? .current : Locale(identifier: captionLanguage) }
}
