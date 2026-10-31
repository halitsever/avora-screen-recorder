import Foundation

/// Anything placed on the timeline between two times, in seconds of the recording.
public protocol TimeSpan: Sendable, Equatable {
    var start: Double { get set }
    var end: Double { get set }
}

extension TimeSpan {
    public var length: Double { end - start }
    public func contains(_ time: Double) -> Bool { time >= start && time <= end }
}

/// A plain stretch of time, such as a range where the cursor is hidden.
public struct TimeRange: TimeSpan, Codable {
    public var start: Double
    public var end: Double

    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }
}

extension ZoomSegment: TimeSpan {}

/// Hand edits to one lane of the timeline. Every change keeps the spans sorted, apart from each
/// other and inside the video, so there is never an overlap to resolve later.
public struct SpanTimeline<Span: TimeSpan>: Sendable, Equatable {
    public static var minimumLength: Double { 0.1 }
    public static var newLength: Double { 3.0 }

    public internal(set) var segments: [Span]
    public let duration: Double
    /// Spans may share time, like blurs over different parts of the screen. They then only stay
    /// inside the video and keep their order, so an index stays put while a span is dragged.
    public let allowsOverlap: Bool

    public init(segments: [Span], duration: Double, allowsOverlap: Bool = false) {
        self.duration = duration
        self.allowsOverlap = allowsOverlap
        self.segments = segments
            .map { var s = $0; s.start = max(s.start, 0); s.end = min(s.end, duration); return s }
            .filter { $0.length >= Self.minimumLength }
            .sorted { $0.start < $1.start }
    }

    public func index(at time: Double) -> Int? {
        segments.firstIndex { $0.contains(time) }
    }

    public mutating func move(_ index: Int, to start: Double) {
        let length = segments[index].length
        let low = lowerBound(index), high = upperBound(index) - length
        segments[index].start = min(max(start, low), max(high, low))
        segments[index].end = segments[index].start + length
    }

    public mutating func setStart(_ index: Int, to time: Double) {
        segments[index].start = min(max(time, lowerBound(index)), segments[index].end - Self.minimumLength)
    }

    public mutating func setEnd(_ index: Int, to time: Double) {
        segments[index].end = max(min(time, upperBound(index)), segments[index].start + Self.minimumLength)
    }

    /// Changes anything but the timing, which only the moves above may touch.
    public mutating func update(_ index: Int, _ change: (inout Span) -> Void) {
        let (start, end) = (segments[index].start, segments[index].end)
        change(&segments[index])
        segments[index].start = start
        segments[index].end = end
    }

    /// Adds a span starting at `time`, shortened or slid back to fit the gap it lands in.
    /// Returns its index, or nil when `time` is inside a span or the gap is too small.
    @discardableResult
    public mutating func add(at time: Double, make: (_ start: Double, _ end: Double) -> Span) -> Int? {
        if allowsOverlap {
            guard time >= 0, time <= duration, duration >= Self.minimumLength else { return nil }
            let start = max(0, min(time, duration - Self.newLength))
            segments.append(make(start, min(duration, start + Self.newLength)))
            return segments.count - 1
        }
        guard index(at: time) == nil, time >= 0, time <= duration else { return nil }
        let next = segments.firstIndex { $0.start > time } ?? segments.count
        let gapStart = next > 0 ? segments[next - 1].end : 0
        let gapEnd = next < segments.count ? segments[next].start : duration
        guard gapEnd - gapStart >= Self.minimumLength else { return nil }

        let start = max(gapStart, min(time, gapEnd - Self.newLength))
        segments.insert(make(start, min(gapEnd, start + Self.newLength)), at: next)
        return next
    }

    public mutating func remove(_ index: Int) {
        segments.remove(at: index)
    }

    private func lowerBound(_ index: Int) -> Double {
        index > 0 && !allowsOverlap ? segments[index - 1].end : 0
    }

    private func upperBound(_ index: Int) -> Double {
        index + 1 < segments.count && !allowsOverlap ? segments[index + 1].start : duration
    }
}

public typealias ZoomTimeline = SpanTimeline<ZoomSegment>

extension SpanTimeline where Span == ZoomSegment {
    @discardableResult
    public mutating func add(at time: Double, scale: Double) -> Int? {
        add(at: time) { ZoomSegment(start: $0, end: $1, scale: scale) }
    }
}
