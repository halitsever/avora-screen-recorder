import CoreGraphics

/// Where a moving element sits during one frame's exposure. Averaging the element drawn at
/// each sample gives motion blur.
public enum MotionTrail {
    /// Output pixels between neighbouring samples.
    public static let spacing = 4.0
    public static let maxSamples = 16

    /// `amount` 1 exposes for 1/60 s at any frame rate, so blur looks the same at 30 and 60 fps.
    public static func rects(from previous: CGRect, to current: CGRect, amount: Double, fps: Double) -> [CGRect] {
        let start = lerp(current, previous, strength(amount, fps))
        let travel = max(abs(start.minX - current.minX), abs(start.minY - current.minY),
                         abs(start.maxX - current.maxX), abs(start.maxY - current.maxY))
        return steps(travel).map { lerp(start, current, $0) }
    }

    public static func points(from previous: CGPoint, to current: CGPoint, amount: Double, fps: Double) -> [CGPoint] {
        let s = strength(amount, fps)
        let start = CGPoint(x: current.x + (previous.x - current.x) * s, y: current.y + (previous.y - current.y) * s)
        let travel = max(abs(start.x - current.x), abs(start.y - current.y))
        return steps(travel).map { t in
            CGPoint(x: start.x + (current.x - start.x) * t, y: start.y + (current.y - start.y) * t)
        }
    }

    private static func strength(_ amount: Double, _ fps: Double) -> Double {
        min(max(amount, 0), 1) * min(fps / 60, 1)
    }

    /// Fractions from the trail start (0) to the current position (1).
    private static func steps(_ travel: Double) -> [Double] {
        let count = min(max(Int((travel / spacing).rounded(.up)), 1), maxSamples)
        guard count > 1 else { return [1] }
        return (0..<count).map { Double($0) / Double(count - 1) }
    }

    private static func lerp(_ a: CGRect, _ b: CGRect, _ t: Double) -> CGRect {
        CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY + (b.minY - a.minY) * t,
               width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
    }
}
