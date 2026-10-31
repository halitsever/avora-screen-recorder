import CoreGraphics
import Foundation

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

    /// A global point inside a recorded window. The window may have moved or been resized since
    /// recording began; capture scales its content to the first size, so the cursor scales too.
    static func pixel(for point: CGPoint, in frame: CGRect, pixelSize: CGSize) -> CGPoint {
        CGPoint(x: (point.x - frame.minX) * pixelSize.width / frame.width,
                y: (point.y - frame.minY) * pixelSize.height / frame.height)
    }

    static func pixelSize(for area: CGRect, scale: Double) -> CGSize {
        CGSize(width: even(area.width * scale), height: even(area.height * scale))
    }

    private static func even(_ value: Double) -> Double {
        (value / 2).rounded(.down) * 2
    }
}

/// The current frame of one window, read 30 times a second while it is recorded.
final class WindowTracker: @unchecked Sendable {
    let windowID: CGWindowID
    private let lock = NSLock()
    private var latest: CGRect
    private var timer: DispatchSourceTimer?

    init(windowID: CGWindowID, frame: CGRect) {
        self.windowID = windowID
        latest = frame
    }

    var frame: CGRect { lock.withLock { latest } }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "avora.window", qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: 1.0 / 30)
        timer.setEventHandler { [weak self] in
            guard let self, let frame = Self.frame(of: windowID) else { return }
            lock.withLock { self.latest = frame }
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// nil once the window is gone; the last known frame is kept then.
    static func frame(of windowID: CGWindowID) -> CGRect? {
        let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]]
        guard let bounds = info?.first?[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds)
    }
}
