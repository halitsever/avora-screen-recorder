import CoreGraphics
import Testing
@testable import ZoomEngine

struct CursorVisibilityTests {
    private func log(_ samples: [(Double, Double)], clicks: [Double] = [], duration: Double = 20) -> InputLog {
        InputLog(
            sourceSize: CGSize(width: 1000, height: 600), pointPixelScale: 1, duration: duration,
            cursor: samples.map { CursorSample(time: $0.0, position: CGPoint(x: $0.1, y: 0)) },
            clicks: clicks.map { ClickEvent(time: $0, position: .zero, isDown: true) }
        )
    }

    @Test func movingCursorStaysVisible() {
        let visibility = CursorVisibility(log: log([(0, 0), (1, 50), (2, 100)]), idleDelay: 2)
        #expect(visibility.opacity(at: 2.5) == 1)
    }

    @Test func restingCursorFadesOutAfterTheDelay() {
        // The repeated sample at 6 s is the recorder re-emitting a resting position.
        let visibility = CursorVisibility(log: log([(0, 0), (1, 50), (6, 50)]), idleDelay: 2)
        #expect(visibility.opacity(at: 2.9) == 1)
        #expect(abs(visibility.opacity(at: 3 + CursorVisibility.fadeOut / 2) - 0.5) < 1e-9)
        #expect(visibility.opacity(at: 5) == 0)
    }

    @Test func movingAgainFadesBackIn() {
        let visibility = CursorVisibility(log: log([(0, 0), (1, 50), (8, 50), (8.01, 60)]), idleDelay: 2)
        #expect(visibility.opacity(at: 7) == 0)
        #expect(abs(visibility.opacity(at: 8.01 + CursorVisibility.fadeIn / 2) - 0.5) < 1e-9)
        #expect(visibility.opacity(at: 9) == 1)
    }

    @Test func clicksCountAsActivity() {
        let visibility = CursorVisibility(log: log([(0, 0), (1, 50)], clicks: [4]), idleDelay: 2)
        #expect(visibility.opacity(at: 5) == 1)
    }

    @Test func hiddenRangesHideTheCursor() {
        let visibility = CursorVisibility(log: log([(0, 0), (1, 50), (2, 100)]), idleDelay: nil,
                                          hidden: [TimeRange(start: 1.5, end: 3)])
        #expect(visibility.opacity(at: 1) == 1)
        #expect(visibility.opacity(at: 2) == 0)
    }

    @Test func freezingHoldsTheLastPositionBeforeTheCutoff() {
        let frozen = log([(0, 0), (8, 80), (10, 500)], duration: 10).freezingCursor(last: 2)
        #expect(Director.rawCursor(at: 9.5, in: frozen.cursor) == CGPoint(x: 80, y: 0))
        #expect(Director.rawCursor(at: 4, in: frozen.cursor) == CGPoint(x: 40, y: 0))
    }
}

struct SpanTimelineTests {
    @Test func hiddenRangesFollowTheSameEditingRules() throws {
        var ranges = SpanTimeline<TimeRange>(segments: [TimeRange(start: 2, end: 4)], duration: 10)
        let added = ranges.add(at: 3.5) { TimeRange(start: $0, end: $1) }
        #expect(added == nil)
        let other = ranges.add(at: 5) { TimeRange(start: $0, end: $1) }
        #expect(other == 1)
        #expect(ranges.segments[1] == TimeRange(start: 5, end: 8))
        ranges.move(1, to: 1)
        #expect(ranges.segments[1] == TimeRange(start: 4, end: 7))
    }

    @Test func overlappingSpansIgnoreTheirNeighbours() {
        var ranges = SpanTimeline<TimeRange>(segments: [TimeRange(start: 2, end: 6), TimeRange(start: 3, end: 5)],
                                             duration: 10, allowsOverlap: true)
        #expect(ranges.segments.count == 2)
        let added = ranges.add(at: 4) { TimeRange(start: $0, end: $1) }
        #expect(added == 2)
        #expect(ranges.segments[2] == TimeRange(start: 4, end: 7))
        ranges.move(1, to: 0.5)
        #expect(ranges.segments[1] == TimeRange(start: 0.5, end: 2.5))
        ranges.setEnd(0, to: 9)
        #expect(ranges.segments[0].end == 9)
    }
}

struct CroppedLogTests {
    @Test func croppingMovesInputIntoTheNewFrame() {
        let log = InputLog(
            sourceSize: CGSize(width: 1000, height: 600), pointPixelScale: 2, duration: 5,
            cursor: [CursorSample(time: 1, position: CGPoint(x: 300, y: 200))],
            clicks: [ClickEvent(time: 2, position: CGPoint(x: 350, y: 250), isDown: true)]
        )
        let cropped = log.cropped(to: CGRect(x: 200, y: 100, width: 400, height: 300))
        #expect(cropped.sourceSize == CGSize(width: 400, height: 300))
        #expect(cropped.cursor[0].position == CGPoint(x: 100, y: 100))
        #expect(cropped.clicks[0].position == CGPoint(x: 150, y: 150))
        #expect(cropped.pointPixelScale == 2)
    }
}
