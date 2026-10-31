import AppKit
import CoreImage
import SwiftUI

enum Brand {
    static let orange = Color(rgb: 0xF26B1D)
    static let peach = Color(rgb: 0xFFD3A1)
    static let ink = Color(rgb: 0x121318)
    static let inkColor = NSColor(srgbRed: 0x12 / 255, green: 0x13 / 255, blue: 0x18 / 255, alpha: 1)

    static var mark: NSImage? { NSImage(named: "AvoraMark") }

    /// Sora ships inside the app bundle; a plain `swift run` falls back to the system font.
    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "Sora", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func wordmarkFont(size: CGFloat) -> Font {
        let weightAxis = 0x7767_6874 // 'wght'
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: "Sora",
            NSFontDescriptor.AttributeName(kCTFontVariationAttribute as String): [weightAxis: 600],
        ])
        guard let font = NSFont(descriptor: descriptor, size: size), font.familyName == "Sora" else {
            return .system(size: size, weight: .semibold)
        }
        return Font(font)
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(.sRGB, red: Double(rgb >> 16 & 0xFF) / 255, green: Double(rgb >> 8 & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

/// Small cached renders of each backdrop for the picker and the menu.
@MainActor
enum BackgroundThumbnails {
    private static var cache: [String: NSImage] = [:]
    private static let context = CIContext()

    static func image(for preset: BackgroundPreset, size: CGSize) -> NSImage {
        let key = "\(preset.id)-\(Int(size.width))x\(Int(size.height))"
        if let cached = cache[key] { return cached }
        let pixels = CGSize(width: size.width * 2, height: size.height * 2)
        let image = context.createCGImage(preset.image(size: pixels), from: CGRect(origin: .zero, size: pixels))
            .map { NSImage(cgImage: $0, size: size) } ?? NSImage(size: size)
        cache[key] = image
        return image
    }
}
