import Foundation

/// A kept part of the recording and how fast it plays. Times are in the recording.
public struct Clip: TimeSpan, Codable {
    public var start: Double
    public var end: Double
    public var speed: Double

    public init(start: Double, end: Double, speed: Double = 1) {
        self.start = start
        self.end = end
        self.speed = speed
    }

    /// How long the clip lasts in the video.
    public var outputLength: Double { length / speed }
}

/// The parts of a recording that make it into the video, in order. Gaps between clips are cut.
public typealias ClipList = SpanTimeline<Clip>

extension SpanTimeline where Span == Clip {
    public static func whole(duration: Double) -> ClipList {
        ClipList(segments: [Clip(start: 0, end: duration)], duration: duration)
    }

    public var outputDuration: Double {
        segments.reduce(0) { $0 + $1.outputLength }
    }

    /// The recording time shown at `output` seconds into the video. A clip's last instant
    /// belongs to the next clip, whose first frame is what plays there.
    public func sourceTime(atOutput output: Double) -> Double {
        var elapsed = 0.0
        for clip in segments {
            if output < elapsed + clip.outputLength {
                return clip.start + max(output - elapsed, 0) * clip.speed
            }
            elapsed += clip.outputLength
        }
        return segments.last?.end ?? 0
    }

    /// Where a moment of the recording lands in the video; nil when it was cut.
    public func outputTime(atSource source: Double) -> Double? {
        var elapsed = 0.0
        for clip in segments {
            if clip.contains(source) { return elapsed + (source - clip.start) / clip.speed }
            elapsed += clip.outputLength
        }
        return nil
    }

    /// Like `outputTime(atSource:)`, but a cut moment lands where the next kept clip starts.
    public func outputTime(snappingSource source: Double) -> Double {
        if let exact = outputTime(atSource: source) { return exact }
        var elapsed = 0.0
        for clip in segments {
            if clip.start > source { return elapsed }
            elapsed += clip.outputLength
        }
        return elapsed
    }

    /// Cuts the clip under `source` in two. Returns the second half's index, or nil when either
    /// half would be shorter than the minimum.
    @discardableResult
    public mutating func split(at source: Double) -> Int? {
        guard let index = index(at: source) else { return nil }
        let clip = segments[index]
        guard source - clip.start >= Self.minimumLength, clip.end - source >= Self.minimumLength else { return nil }
        segments[index].end = source
        segments.insert(Clip(start: source, end: clip.end, speed: clip.speed), at: index + 1)
        return index + 1
    }
}

/// Stretches of steady typing, which are worth speeding up in a video.
public enum TypingBursts {
    /// Keys less than `gap` apart belong together; a burst lasts at least `minLength` seconds
    /// at `minRate` keys a second or more.
    public static func find(in times: [Double], gap: Double = 0.5, minLength: Double = 1.5, minRate: Double = 2) -> [TimeRange] {
        var bursts: [TimeRange] = []
        var group: [Double] = []
        func close() {
            if let first = group.first, let last = group.last, last - first >= minLength, Double(group.count) / (last - first) >= minRate {
                bursts.append(TimeRange(start: first, end: last))
            }
            group = []
        }
        for time in times.sorted() {
            if let last = group.last, time - last > gap { close() }
            group.append(time)
        }
        close()
        return bursts
    }
}

extension SpanTimeline where Span == Clip {
    /// Plays the given stretches at `speed`. Clips already sped up or slowed down keep their speed.
    public mutating func speedUp(_ ranges: [TimeRange], to speed: Double) {
        for range in ranges {
            for boundary in [range.start, range.end] {
                if let index = index(at: boundary), segments[index].speed == 1 { split(at: boundary) }
            }
            for index in segments.indices where segments[index].speed == 1
                && segments[index].start >= range.start - 1e-9 && segments[index].end <= range.end + 1e-9 {
                segments[index].speed = speed
            }
        }
    }
}
