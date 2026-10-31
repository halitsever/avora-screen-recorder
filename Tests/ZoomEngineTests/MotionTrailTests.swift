import CoreGraphics
import Testing
@testable import ZoomEngine

struct MotionTrailTests {
    private let still = CGRect(x: 100, y: 100, width: 800, height: 500)

    @Test func stillScreenGetsOneSample() {
        #expect(MotionTrail.rects(from: still, to: still, amount: 1, fps: 60) == [still])
    }

    @Test func zeroAmountTurnsBlurOff() {
        let moved = still.offsetBy(dx: 80, dy: 0)
        #expect(MotionTrail.rects(from: still, to: moved, amount: 0, fps: 60) == [moved])
    }

    @Test func fullAmountAtSixtyFpsSpansTheWholeFrame() {
        let moved = still.offsetBy(dx: 40, dy: 0)
        let samples = MotionTrail.rects(from: still, to: moved, amount: 1, fps: 60)
        #expect(samples.first == still)
        #expect(samples.last == moved)
        #expect(samples.count == 10)
    }

    @Test func thirtyFpsKeepsTheSameExposureTime() {
        let moved = still.offsetBy(dx: 40, dy: 0)
        let samples = MotionTrail.rects(from: still, to: moved, amount: 1, fps: 30)
        #expect(samples.first?.minX == 120)
        #expect(samples.last == moved)
    }

    @Test func zoomCountsTheFastestMovingEdge() {
        let zoomed = still.insetBy(dx: -30, dy: -10)
        #expect(MotionTrail.rects(from: still, to: zoomed, amount: 1, fps: 60).count == 8)
    }

    @Test func longMovesAreCappedAtSixteenSamples() {
        let far = still.offsetBy(dx: 900, dy: 0)
        #expect(MotionTrail.rects(from: still, to: far, amount: 1, fps: 60).count == 16)
    }

    @Test func cursorTrailFollowsTheSameRules() {
        let samples = MotionTrail.points(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 20), amount: 1, fps: 60)
        #expect(samples.count == 5)
        #expect(samples.first == CGPoint(x: 0, y: 0))
        #expect(samples.last == CGPoint(x: 0, y: 20))
    }
}
