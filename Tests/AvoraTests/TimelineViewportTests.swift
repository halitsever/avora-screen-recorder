import Foundation
import Testing
@testable import Avora

@MainActor
struct TimelineViewportTests {
    @Test func startsShowingTheWholeRecording() {
        let viewport = TimelineViewport(duration: 60)
        #expect(viewport.start == 0)
        #expect(viewport.span == 60)
        #expect(!viewport.isZoomed)
        #expect(viewport.x(30, width: 600) == 300)
        #expect(viewport.time(atX: 150, width: 600) == 15)
    }

    @Test func zoomingKeepsTheMomentUnderThePointerInPlace() {
        let viewport = TimelineViewport(duration: 60)
        let before = viewport.x(45, width: 600)
        viewport.zoom(by: 4, around: 45)
        #expect(viewport.span == 15)
        #expect(abs(viewport.x(45, width: 600) - before) < 1e-6)
    }

    @Test func zoomStopsAtOneSecondAndAtTheWholeRecording() {
        let viewport = TimelineViewport(duration: 60)
        viewport.zoom(by: 1000, around: 10)
        #expect(viewport.span == TimelineViewport.minimumSpan)
        viewport.zoom(by: 0.0001, around: 10)
        #expect(viewport.span == 60)
        #expect(viewport.start == 0)
    }

    @Test func scrollingStaysInsideTheRecording() {
        let viewport = TimelineViewport(duration: 60)
        viewport.zoom(by: 6, around: 0)
        viewport.scroll(by: -5)
        #expect(viewport.start == 0)
        viewport.scroll(by: 500)
        #expect(viewport.start == 50)
    }

    @Test func revealPagesAheadWhenThePlayheadLeavesTheView() {
        let viewport = TimelineViewport(duration: 60)
        viewport.zoom(by: 6, around: 0)
        viewport.reveal(5)
        #expect(viewport.start == 0)
        viewport.reveal(12)
        #expect(viewport.start <= 12 && viewport.end > 12)
        viewport.reveal(1)
        #expect(viewport.start <= 1 && viewport.end > 1)
    }
}

struct SnapTests {
    @Test func snapsToTheClosestCandidateWithinTolerance() {
        #expect(Snap.time(4.93, to: [2, 5, 9], tolerance: 0.1) == 5)
        #expect(Snap.time(4.7, to: [2, 5, 9], tolerance: 0.1) == 4.7)
    }

    @Test func aMovedSpanSnapsByWhicheverEdgeIsCloser() {
        // The end lands 0.04 from 8, the start 0.3 from 2.
        #expect(Snap.start(2.3, length: 5.66, to: [2, 8], tolerance: 0.1) == 8 - 5.66)
        #expect(Snap.start(2.05, length: 3, to: [2, 8], tolerance: 0.1) == 2)
    }
}

struct TimeTextTests {
    @Test func readsSecondsAndClockTimes() {
        #expect(TimeText.parse("2.5") == 2.5)
        #expect(TimeText.parse("2,5") == 2.5)
        #expect(TimeText.parse(" 3 s ") == 3)
        #expect(TimeText.parse("1:02.25") == 62.25)
        #expect(TimeText.parse("1:00:01") == 3601)
        #expect(TimeText.parse("abc") == nil)
        #expect(TimeText.parse("") == nil)
    }

    @Test func clockRoundsToTheNearestHundredth() {
        #expect(clock(10.7 - 1e-9) == "0:10.70")
        #expect(clock(59.996) == "1:00.00")
        #expect(clock(0) == "0:00.00")
    }
}
