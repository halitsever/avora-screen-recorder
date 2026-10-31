import CoreGraphics

/// Where things are on one output frame. `screenRect` is in output canvas coordinates
/// (top-left origin); `cursor` is in source video pixels.
public struct FrameState: Sendable, Equatable {
    public var screenRect: CGRect
    public var cursor: CGPoint?
    public var cursorShape: Int?
}

/// Turns an input log into a per-frame camera and cursor track.
public struct Director: Sendable {
    public var log: InputLog
    public var base: CGRect
    /// The area a zoom must fill; nil uses `base`.
    public var stage: CGRect?
    public var zoom: ZoomConfig
    /// Zooms edited by hand. nil makes them from the clicks.
    public var segments: [ZoomSegment]?
    public var screenSpring: SpringConfig
    /// nil draws the cursor exactly where it was recorded.
    public var cursorSpring: SpringConfig?

    /// Cursor jitter below this many points is ignored when picking what to look at.
    static let minFocusMove = 10.0

    public init(
        log: InputLog,
        base: CGRect,
        stage: CGRect? = nil,
        zoom: ZoomConfig = ZoomConfig(),
        segments: [ZoomSegment]? = nil,
        screenSpring: SpringConfig = .screen,
        cursorSpring: SpringConfig? = .cursor
    ) {
        self.log = log
        self.base = base
        self.stage = stage
        self.zoom = zoom
        self.segments = segments
        self.screenSpring = screenSpring
        self.cursorSpring = cursorSpring
    }

    public func frames(fps: Double) -> [FrameState] {
        let count = Int((log.duration * fps + 1e-9).rounded(.down))
        guard count > 0 else { return [] }

        let plan = focusPlan()
        let dt = 1 / fps
        var rect: [Spring] = []
        var cursor: [Spring] = []
        var states: [FrameState] = []
        states.reserveCapacity(count)

        for index in 0..<count {
            let time = Double(index) * dt
            let target = targetRect(at: time, plan: plan)
            let targetValues: [Double] = [target.minX, target.minY, target.width, target.height]
            rect = Self.follow(rect, targetValues, dt, screenSpring)

            let raw = Self.rawCursor(at: time, in: log.cursor)
            if let raw, let cursorSpring {
                cursor = Self.follow(cursor, [Double(raw.x), Double(raw.y)], dt, cursorSpring)
            }

            states.append(FrameState(
                screenRect: CGRect(x: rect[0].value, y: rect[1].value, width: rect[2].value, height: rect[3].value),
                cursor: raw.map { cursorSpring == nil ? $0 : CGPoint(x: cursor[0].value, y: cursor[1].value) },
                cursorShape: Self.latestSample(at: time, in: log.cursor)?.shape
            ))
        }
        return states
    }

    /// Linear interpolation between neighbouring samples, clamped to the first and last one.
    static func rawCursor(at time: Double, in samples: [CursorSample]) -> CGPoint? {
        guard let first = samples.first else { return nil }
        guard let index = latestIndex(at: time, in: samples) else { return first.position }
        let a = samples[index]
        guard index + 1 < samples.count else { return a.position }
        let b = samples[index + 1]
        let span = b.time - a.time
        let t = span > 0 ? (time - a.time) / span : 1
        return CGPoint(x: a.position.x + (b.position.x - a.position.x) * t,
                       y: a.position.y + (b.position.y - a.position.y) * t)
    }

    private func focusPlan() -> [(segment: ZoomSegment, clusters: [FocusCluster])] {
        let segments = self.segments ?? ZoomSegments.make(clickTimes: log.clicks.map(\.time), duration: log.duration, config: zoom)
        return segments.map { segment in
            if segment.focus != nil { return (segment, []) }
            var points = log.cursor.filter { segment.contains($0.time) }
                .map { TimedPoint(time: $0.time, position: $0.position, isClick: false) }
            points += log.clicks.filter { segment.contains($0.time) }
                .map { TimedPoint(time: $0.time, position: $0.position, isClick: true) }
            points.sort { $0.time < $1.time }
            if let before = log.cursor.last(where: { $0.time < segment.start }) {
                points.insert(TimedPoint(time: segment.start, position: before.position, isClick: false), at: 0)
            }

            let thinned = FocusPlanner.thin(points, minDistance: Self.minFocusMove * log.pointPixelScale)
            let span = FocusPlanner.clusterSpan(sourceSize: log.sourceSize, scale: segment.scale)
            return (segment, FocusPlanner.clusters(thinned, maxSpan: span))
        }
    }

    private func targetRect(at time: Double, plan: [(segment: ZoomSegment, clusters: [FocusCluster])]) -> CGRect {
        guard let active = plan.first(where: { $0.segment.contains(time) }) else { return base }
        if let manual = active.segment.focus {
            return Framing.zoomedRect(base: base, scale: active.segment.scale,
                                      focus01: CGPoint(x: min(max(manual.x, 0), 1), y: min(max(manual.y, 0), 1)), stage: stage)
        }
        guard let focus = FocusPlanner.focus(at: time, in: active.clusters) else { return base }
        let focus01 = CGPoint(
            x: min(max(focus.x / log.sourceSize.width, 0), 1),
            y: min(max(focus.y / log.sourceSize.height, 0), 1)
        )
        return Framing.zoomedRect(base: base, scale: active.segment.scale, focus01: focus01, stage: stage)
    }

    /// Starts springs at rest on the first target, then advances them every frame.
    private static func follow(_ springs: [Spring], _ targets: [Double], _ dt: Double, _ config: SpringConfig) -> [Spring] {
        guard springs.count == targets.count else { return targets.map { Spring(value: $0) } }
        return zip(springs, targets).map { spring, target in
            var spring = spring
            spring.advance(toward: target, by: dt, config: config)
            return spring
        }
    }

    private static func latestSample(at time: Double, in samples: [CursorSample]) -> CursorSample? {
        latestIndex(at: time, in: samples).map { samples[$0] } ?? samples.first
    }

    private static func latestIndex(at time: Double, in samples: [CursorSample]) -> Int? {
        var low = 0, high = samples.count
        while low < high {
            let mid = (low + high) / 2
            if samples[mid].time <= time { low = mid + 1 } else { high = mid }
        }
        return low > 0 ? low - 1 : nil
    }
}
