import CoreGraphics
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

    enum Quality: String, Codable, CaseIterable {
        case studio, social, web
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
    var fps = 60
    var quality = Quality.social
    var zoom = 2.0
    var padding = 0.06
    var cornerRadius = 0.012
    var shadow = 0.45
    var cursorScale = 1.5
    var smoothing = Smoothing.smooth
    var motionBlur = 1.0

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
    }
}

private func even(_ value: Double) -> Double { (value / 2).rounded() * 2 }
