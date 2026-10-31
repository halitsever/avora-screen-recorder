import CoreGraphics

/// What gets recorded: the whole display under the mouse, one window's area, or a dragged area.
enum CaptureMode: String, CaseIterable {
    case screen, window, area
}

/// Rect math for area and window recording. "Global" rects use Quartz display space
/// (top-left origin of the main display, y down); "Cocoa" rects use AppKit's y-up screen space.
enum CaptureGeometry {
    static let minimumSize = 150.0

    static func globalRect(fromCocoa rect: CGRect, mainHeight: Double) -> CGRect {
        CGRect(x: rect.minX, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func cocoaRect(fromGlobal rect: CGRect, mainHeight: Double) -> CGRect {
        CGRect(x: rect.minX, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The dragged rectangle kept inside `display`, or nil while it is smaller than the minimum.
    static func selection(from start: CGPoint, to end: CGPoint, within display: CGRect) -> CGRect? {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
            .intersection(display)
        guard !rect.isNull, rect.width >= minimumSize, rect.height >= minimumSize else { return nil }
        return rect
    }

    static func bestDisplay(for area: CGRect, among displays: [CGRect]) -> Int? {
        let overlaps = displays.map { display -> Double in
            let shared = display.intersection(area)
            return shared.isNull ? 0 : shared.width * shared.height
        }
        guard let best = overlaps.indices.max(by: { overlaps[$0] < overlaps[$1] }), overlaps[best] > 0 else { return nil }
        return best
    }

    /// `area` in the display's own points, which is what ScreenCaptureKit's `sourceRect` takes.
    static func sourceRect(for area: CGRect, on display: CGRect) -> CGRect {
        area.offsetBy(dx: -display.minX, dy: -display.minY)
    }

    static func pixelSize(for area: CGRect, scale: Double) -> CGSize {
        CGSize(width: even(area.width * scale), height: even(area.height * scale))
    }

    private static func even(_ value: Double) -> Double {
        (value / 2).rounded(.down) * 2
    }
}
