import CoreGraphics

public enum Framing {
    /// Scales `base` so the point at `focus01` sits on the base center, then slides it back
    /// until it fully covers `base` again, so zooming near an edge never reveals the backdrop.
    public static func zoomedRect(base: CGRect, scale: Double, focus01: CGPoint) -> CGRect {
        let size = CGSize(width: base.width * scale, height: base.height * scale)
        let x = base.midX - focus01.x * size.width
        let y = base.midY - focus01.y * size.height
        return CGRect(
            x: cover(x, length: size.width, within: base.minX, base.width),
            y: cover(y, length: size.height, within: base.minY, base.height),
            width: size.width,
            height: size.height
        )
    }

    private static func cover(_ origin: Double, length: Double, within start: Double, _ span: Double) -> Double {
        guard length > span else { return start + (span - length) / 2 }
        return min(max(origin, start + span - length), start)
    }
}
