import CoreGraphics

public enum Framing {
    /// Scales `base` so the point at `focus01` sits in the middle, then slides it back until it
    /// fully covers `stage` again, so zooming near an edge never reveals the backdrop. When the
    /// stage is taller or wider than the resting screen, as in vertical video, the zoom goes at
    /// least far enough to fill it. Without a stage the resting frame is the stage.
    public static func zoomedRect(base: CGRect, scale: Double, focus01: CGPoint, stage: CGRect? = nil) -> CGRect {
        let stage = stage ?? base
        let fill = max(stage.width / base.width, stage.height / base.height)
        let level = max(scale, fill)
        let size = CGSize(width: base.width * level, height: base.height * level)
        let x = stage.midX - focus01.x * size.width
        let y = stage.midY - focus01.y * size.height
        return CGRect(
            x: cover(x, length: size.width, within: stage.minX, stage.width),
            y: cover(y, length: size.height, within: stage.minY, stage.height),
            width: size.width,
            height: size.height
        )
    }

    private static func cover(_ origin: Double, length: Double, within start: Double, _ span: Double) -> Double {
        guard length > span else { return start + (span - length) / 2 }
        return min(max(origin, start + span - length), start)
    }
}
