import Foundation

/// Tunables for automatic zoom. Times are in seconds.
public struct ZoomConfig: Sendable, Equatable {
    public var scale: Double
    public var leadIn: Double
    public var hold: Double
    public var mergeGap: Double
    public var ignoreClicksInLast: Double
    public var endMargin: Double

    public init(
        scale: Double = 2.0,
        leadIn: Double = 0.3,
        hold: Double = 2.5,
        mergeGap: Double = 2.5,
        ignoreClicksInLast: Double = 1.0,
        endMargin: Double = 0.8
    ) {
        self.scale = scale
        self.leadIn = leadIn
        self.hold = hold
        self.mergeGap = mergeGap
        self.ignoreClicksInLast = ignoreClicksInLast
        self.endMargin = endMargin
    }
}

public struct ZoomSegment: Sendable, Equatable {
    public var start: Double
    public var end: Double
    public var scale: Double

    public func contains(_ time: Double) -> Bool { time >= start && time <= end }
}

public enum ZoomSegments {
    /// Opens a window around every click and merges windows whose gap is shorter than `mergeGap`.
    public static func make(clickTimes: [Double], duration: Double, config: ZoomConfig) -> [ZoomSegment] {
        let latestEnd = duration - config.endMargin
        let windows = clickTimes
            .filter { $0 < duration - config.ignoreClicksInLast }
            .sorted()
            .map { (start: max($0 - config.leadIn, 0), end: min($0 + config.hold, latestEnd)) }
            .filter { $0.end > $0.start }

        var merged: [ZoomSegment] = []
        for window in windows {
            if let last = merged.last, last.end + config.mergeGap >= window.start {
                merged[merged.count - 1].end = max(last.end, window.end)
            } else {
                merged.append(ZoomSegment(start: window.start, end: window.end, scale: config.scale))
            }
        }
        return merged
    }
}
