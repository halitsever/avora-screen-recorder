import Foundation

/// Hand edits to a recording's zooms. Every change keeps the zooms sorted, apart from each
/// other and inside the video, so there is never an overlap to resolve later.
public struct ZoomTimeline: Sendable, Equatable {
    public static let minimumLength = 0.1
    public static let newLength = 3.0

    public private(set) var segments: [ZoomSegment]
    public let duration: Double

    public init(segments: [ZoomSegment], duration: Double) {
        self.duration = duration
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

    public mutating func update(_ index: Int, _ change: (inout ZoomSegment) -> Void) {
        var segment = segments[index]
        change(&segment)
        segments[index].scale = segment.scale
        segments[index].focus = segment.focus
    }

    /// Adds a zoom starting at `time`, shortened or slid back to fit the gap it lands in.
    /// Returns its index, or nil when `time` is inside a zoom or the gap is too small.
    @discardableResult
    public mutating func add(at time: Double, scale: Double) -> Int? {
        guard index(at: time) == nil, time >= 0, time <= duration else { return nil }
        let next = segments.firstIndex { $0.start > time } ?? segments.count
        let gapStart = next > 0 ? segments[next - 1].end : 0
        let gapEnd = next < segments.count ? segments[next].start : duration
        guard gapEnd - gapStart >= Self.minimumLength else { return nil }

        let start = max(gapStart, min(time, gapEnd - Self.newLength))
        let end = min(gapEnd, start + Self.newLength)
        segments.insert(ZoomSegment(start: start, end: end, scale: scale), at: next)
        return next
    }

    public mutating func remove(_ index: Int) {
        segments.remove(at: index)
    }

    private func lowerBound(_ index: Int) -> Double {
        index > 0 ? segments[index - 1].end : 0
    }

    private func upperBound(_ index: Int) -> Double {
        index + 1 < segments.count ? segments[index + 1].start : duration
    }
}
