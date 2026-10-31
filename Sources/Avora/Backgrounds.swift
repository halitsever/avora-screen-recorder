import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct RGB: Equatable {
    let hex: UInt32

    init(_ hex: UInt32) { self.hex = hex }

    /// Six hex digits, with or without a leading #.
    init?(hexString: String) {
        let digits = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        hex = value
    }

    var hexString: String { String(format: "%06X", hex) }

    func ciColor(alpha: Double = 1) -> CIColor {
        CIColor(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255, alpha: alpha,
                colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)!
    }
}

/// A soft spot of color that fades out to transparent at `radius`.
struct Blob: Equatable {
    let center: CGPoint
    let radius: Double
    let color: RGB
}

/// Points are in unit space with a top-left origin. Radii are fractions of the longer side.
enum BackgroundFill: Equatable {
    case linear(from: RGB, to: RGB)
    case radial(center: CGPoint, radius: Double, inner: RGB, outer: RGB)
    case mesh(base: RGB, blobs: [Blob])
    case solid(RGB)
    /// A picture scaled to cover the canvas and centered.
    case image(URL)
}

struct BackgroundPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let fill: BackgroundFill

    static let defaultID = "avora"

    static let all: [BackgroundPreset] = [
        BackgroundPreset(id: "avora", name: "Avora", fill: .linear(from: RGB(0xF26B1D), to: RGB(0xFFD3A1))),
        BackgroundPreset(id: "ember", name: "Ember", fill: .linear(from: RGB(0x2A1A12), to: RGB(0xF26B1D))),
        BackgroundPreset(id: "grove", name: "Grove", fill: .linear(from: RGB(0x2F6B3A), to: RGB(0x121318))),
        BackgroundPreset(id: "studio", name: "Studio", fill: .radial(
            center: CGPoint(x: 0.5, y: 0.3), radius: 0.4, inner: RGB(0x2C2C33), outer: RGB(0x15151A))),
        BackgroundPreset(id: "sand", name: "Sand", fill: .radial(
            center: CGPoint(x: 0.5, y: 0.3), radius: 0.4, inner: RGB(0x6B5A45), outer: RGB(0x2A2218))),
        BackgroundPreset(id: "aurora", name: "Aurora", fill: .mesh(base: RGB(0x0A0A0E), blobs: [
            Blob(center: CGPoint(x: 0.25, y: 0.25), radius: 0.3, color: RGB(0x4A3370)),
            Blob(center: CGPoint(x: 0.75, y: 0.7), radius: 0.34, color: RGB(0x2A4D7A)),
            Blob(center: CGPoint(x: 0.5, y: 0.5), radius: 0.22, color: RGB(0x1A3A3A)),
        ])),
        BackgroundPreset(id: "iris", name: "Iris", fill: .linear(from: RGB(0x667EEA), to: RGB(0x764BA2))),
        BackgroundPreset(id: "blossom", name: "Blossom", fill: .linear(from: RGB(0xF093FB), to: RGB(0xF5576C))),
        BackgroundPreset(id: "sky", name: "Sky", fill: .linear(from: RGB(0x4FACFE), to: RGB(0x00F2FE))),
        BackgroundPreset(id: "mint", name: "Mint", fill: .linear(from: RGB(0x43E97B), to: RGB(0x38F9D7))),
        BackgroundPreset(id: "sunset", name: "Sunset", fill: .linear(from: RGB(0xFF8A00), to: RGB(0xE52E71))),
        BackgroundPreset(id: "indigo", name: "Indigo", fill: .linear(from: RGB(0x0EA5E9), to: RGB(0x7C3AED))),
    ]

    /// Presets by id, plus `color:RRGGBB`, `image:<path>` and `wallpaper`. Anything unknown
    /// falls back to the default gradient.
    static func named(_ id: String?) -> BackgroundPreset {
        let fallback = all.first { $0.id == defaultID }!
        guard let id else { return fallback }
        if let preset = all.first(where: { $0.id == id }) { return preset }
        if id.hasPrefix(colorPrefix), let color = RGB(hexString: String(id.dropFirst(colorPrefix.count))) {
            return BackgroundPreset(id: colorPrefix + color.hexString, name: "Color", fill: .solid(color))
        }
        if id.hasPrefix(imagePrefix) {
            let url = URL(fileURLWithPath: String(id.dropFirst(imagePrefix.count)))
            return BackgroundPreset(id: id, name: url.deletingPathExtension().lastPathComponent, fill: .image(url))
        }
        if id == wallpaperID, let screen = NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen) {
            return BackgroundPreset(id: id, name: "Wallpaper", fill: .image(url))
        }
        return fallback
    }

    static let colorPrefix = "color:"
    static let imagePrefix = "image:"
    static let wallpaperID = "wallpaper"


    /// Renders the backdrop in Core Image space (bottom-left origin), cropped to `size`.
    func image(size: CGSize) -> CIImage {
        let bounds = CGRect(origin: .zero, size: size)
        let longSide = max(size.width, size.height)
        let point = { (unit: CGPoint) in CGPoint(x: unit.x * size.width, y: (1 - unit.y) * size.height) }

        switch fill {
        case let .linear(from, to):
            let filter = CIFilter.linearGradient()
            filter.point0 = point(CGPoint(x: 0, y: 0))
            filter.point1 = point(CGPoint(x: 1, y: 1))
            filter.color0 = from.ciColor()
            filter.color1 = to.ciColor()
            return filter.outputImage!.cropped(to: bounds)

        case let .radial(center, radius, inner, outer):
            return Self.radial(at: point(center), radius: radius * longSide, inner.ciColor(), outer.ciColor())
                .cropped(to: bounds)

        case let .mesh(base, blobs):
            return blobs.reduce(CIImage(color: base.ciColor())) { image, blob in
                Self.radial(at: point(blob.center), radius: blob.radius * longSide,
                            blob.color.ciColor(), blob.color.ciColor(alpha: 0))
                    .composited(over: image)
            }
            .cropped(to: bounds)

        case let .solid(color):
            return CIImage(color: color.ciColor()).cropped(to: bounds)

        case let .image(url):
            guard let picture = CIImage(contentsOf: url), picture.extent.width > 0, picture.extent.height > 0 else {
                return Self.named(nil).image(size: size)
            }
            let scale = max(size.width / picture.extent.width, size.height / picture.extent.height)
            let scaled = picture.transformed(by: CGAffineTransform(translationX: -picture.extent.minX, y: -picture.extent.minY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale)))
            let offset = CGAffineTransform(translationX: (size.width - scaled.extent.width) / 2, y: (size.height - scaled.extent.height) / 2)
            return scaled.transformed(by: offset).cropped(to: bounds)
        }
    }

    private static func radial(at center: CGPoint, radius: Double, _ inner: CIColor, _ outer: CIColor) -> CIImage {
        let filter = CIFilter.radialGradient()
        filter.center = center
        filter.radius0 = 0
        filter.radius1 = Float(radius)
        filter.color0 = inner
        filter.color1 = outer
        return filter.outputImage!
    }
}
