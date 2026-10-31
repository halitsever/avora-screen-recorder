import Foundation

/// Host time with the paused stretches cut out. Video, audio and input all pass their timestamps
/// through one clock, so they stay in sync across pauses. Times are host seconds.
final class RecordingClock: @unchecked Sendable {
    private let lock = NSLock()
    private var pausedAt: Double?
    private var gaps: [(start: Double, end: Double)] = []

    var isPaused: Bool { lock.withLock { pausedAt != nil } }

    var pausedDuration: Double {
        lock.withLock { gaps.reduce(0) { $0 + $1.end - $1.start } }
    }

    func pause(at time: Double = HostClock.now()) {
        lock.withLock { if pausedAt == nil { pausedAt = time } }
    }

    func resume(at time: Double = HostClock.now()) {
        lock.withLock {
            guard let start = pausedAt else { return }
            gaps.append((start, max(time, start)))
            pausedAt = nil
        }
    }

    /// nil when `host` falls inside a pause, so the sample is dropped.
    func recordingTime(forHost host: Double) -> Double? {
        lock.withLock {
            if let pausedAt, host >= pausedAt { return nil }
            var shift = 0.0
            for gap in gaps {
                if host >= gap.end { shift += gap.end - gap.start }
                else if host >= gap.start { return nil }
            }
            return host - shift
        }
    }

    /// Where a recording stopped at `host` ends; a recording stopped while paused ends at the pause.
    func recordingTime(endingAt host: Double) -> Double {
        lock.withLock {
            let end = pausedAt.map { min($0, host) } ?? host
            return end - gaps.filter { $0.end <= end }.reduce(0) { $0 + $1.end - $1.start }
        }
    }
}
