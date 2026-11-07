import AppKit
import CoreImage
import SwiftUI

enum Brand {
    static let orange = Color(rgb: 0xF26B1D)
    static let peach = Color(rgb: 0xFFD3A1)
    static let ink = Color(rgb: 0x121318)
    static let inkColor = NSColor(srgbRed: 0x12 / 255, green: 0x13 / 255, blue: 0x18 / 255, alpha: 1)
    static let orangeColor = NSColor(srgbRed: 0xF2 / 255, green: 0x6B / 255, blue: 0x1D / 255, alpha: 1)

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

/// shadcn/ui's dark zinc colors for the editor and Settings, which leave color to what needs telling apart.
enum Palette {
    static let background = Color(rgb: 0x09090B)
    static let backgroundColor = NSColor(srgbRed: 0x09 / 255, green: 0x09 / 255, blue: 0x0B / 255, alpha: 1)
    static let surface = Color(rgb: 0x18181B)
    static let border = Color(rgb: 0x27272A)
    static let muted = Color(rgb: 0xA1A1AA)
    static let foreground = Color(rgb: 0xFAFAFA)
    /// Controls take this instead of an accent color.
    static let tint = Color(rgb: 0xE4E4E7)
}

/// shadcn's primary button: near-white with dark text.
struct SolidButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.background)
            .padding(.horizontal, 14).frame(height: 30)
            .background(Palette.foreground.opacity(configuration.isPressed ? 0.85 : isEnabled ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 7))
    }
}
