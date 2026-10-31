import CoreGraphics
import Foundation

/// How visible the drawn cursor is at a moment: hidden in hand-picked ranges, and faded out
/// after it rests for `idleDelay` seconds when that is set.
public struct CursorVisibility: Sendable {
    public static let fadeOut = 0.4
    public static let fadeIn = 0.15

    private let activity: [Double]
    private let idleDelay: Double?
    private let hidden: [TimeRange]

    public init(log: InputLog, idleDelay: Double?, hidden: [TimeRange] = []) {
        self.idleDelay = idleDelay
        self.hidden = hidden
        // The recorder repeats a resting position before each move, so only changes count.
        var moves: [Double] = []
        for (previous, sample) in zip(log.cursor, log.cursor.dropFirst()) where sample.position != previous.position {
            moves.append(sample.time)
        }
        activity = (moves + log.clicks.map(\.time)).sorted()
    }

    public func opacity(at time: Double) -> Double {
        if hidden.contains(where: { $0.contains(time) }) { return 0 }
        guard let idleDelay, let last = latestActivity(atOrBefore: time) else { return 1 }
        let out = min(max((time - last.time - idleDelay) / Self.fadeOut, 0), 1)
        let wasHidden = last.previous.map { last.time - $0 > idleDelay } ?? false
        let fadeIn = wasHidden ? min(max((time - last.time) / Self.fadeIn, 0), 1) : 1
        return fadeIn * (1 - out)
    }

    private func latestActivity(atOrBefore time: Double) -> (time: Double, previous: Double?)? {
        var low = 0, high = activity.count
        while low < high {
            let mid = (low + high) / 2
            if activity[mid] <= time { low = mid + 1 } else { high = mid }
        }
        guard low > 0 else { return nil }
        return (activity[low - 1], low > 1 ? activity[low - 2] : nil)
    }
}

extension InputLog {
    /// The cursor stops moving `seconds` before the end, so reaching for Stop stays out of the video.
    public func freezingCursor(last seconds: Double) -> InputLog {
        guard seconds > 0 else { return self }
        let cutoff = max(duration - seconds, 0)
        var log = self
        if let held = Director.rawCursor(at: cutoff, in: cursor) {
            let shape = cursor.last { $0.time <= cutoff }?.shape
            log.cursor = cursor.filter { $0.time < cutoff } + [CursorSample(time: cutoff, position: held, shape: shape)]
        }
        return log
    }
}

extension InputLog {
    /// The same input seen through a crop of the recording, in the crop's own pixels. Clicks
    /// outside the crop are dropped so they cannot pull the camera toward something cut away.
    public func cropped(to rect: CGRect) -> InputLog {
        var log = self
        let shift = { (point: CGPoint) in CGPoint(x: point.x - rect.minX, y: point.y - rect.minY) }
        log.sourceSize = rect.size
        log.cursor = cursor.map { CursorSample(time: $0.time, position: shift($0.position), shape: $0.shape) }
        log.clicks = clicks.filter { rect.contains($0.position) }
            .map { ClickEvent(time: $0.time, position: shift($0.position), isDown: $0.isDown) }
        return log
    }
}
