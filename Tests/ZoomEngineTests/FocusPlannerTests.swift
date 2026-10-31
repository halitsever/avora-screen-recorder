import CoreGraphics
import Testing
@testable import ZoomEngine

private func move(_ t: Double, _ x: Double, _ y: Double) -> TimedPoint {
    TimedPoint(time: t, position: CGPoint(x: x, y: y), isClick: false)
}

private func click(_ t: Double, _ x: Double, _ y: Double) -> TimedPoint {
    TimedPoint(time: t, position: CGPoint(x: x, y: y), isClick: true)
}

struct FocusPlannerTests {
    @Test func thinningDropsSmallMovesButKeepsClicks() {
        let points = [move(0, 0, 0), move(0.1, 3, 4), click(0.2, 4, 4), move(0.3, 20, 0)]
        let kept = FocusPlanner.thin(points, minDistance: 10)
        #expect(kept.map(\.time) == [0, 0.2, 0.3])
    }

    @Test func pointsInsideSpanFormOneCluster() {
        let points = [move(0, 0, 0), move(1, 50, 50), move(2, 90, 10)]
        let clusters = FocusPlanner.clusters(points, maxSpan: CGSize(width: 100, height: 100))
        #expect(clusters.count == 1)
    }

    @Test func leavingSpanStartsNewCluster() throws {
        let points = [move(0, 0, 0), move(1, 50, 0), move(2, 0, 150)]
        let clusters = FocusPlanner.clusters(points, maxSpan: CGSize(width: 100, height: 100))
        try #require(clusters.count == 2)
        #expect(clusters[1].start == 2)
    }

    @Test func clusterCenterIsWeightedByDwellTime() throws {
        let points = [move(0, 0, 0), move(3, 100, 0)]
        let clusters = FocusPlanner.clusters(points, maxSpan: CGSize(width: 200, height: 200))
        let center = try #require(clusters.first?.center)
        // (0,0) is held for 3s, (100,0) only for the 0.1s tail.
        #expect(abs(center.x - 100 * 0.1 / 3.1) < 1e-6)
    }

    @Test func lastPointOfClusterDwellsUntilNextClusterStarts() throws {
        let points = [move(0, 0, 0), move(1, 100, 0), move(4, 1000, 1000)]
        let clusters = FocusPlanner.clusters(points, maxSpan: CGSize(width: 200, height: 200))
        let center = try #require(clusters.first?.center)
        #expect(abs(center.x - 100 * 3.0 / 4.0) < 1e-6)
    }

    @Test func focusUsesLatestStartedCluster() {
        let clusters = [
            FocusCluster(start: 0, center: CGPoint(x: 1, y: 1)),
            FocusCluster(start: 5, center: CGPoint(x: 2, y: 2)),
        ]
        #expect(FocusPlanner.focus(at: 4.9, in: clusters) == CGPoint(x: 1, y: 1))
        #expect(FocusPlanner.focus(at: 5, in: clusters) == CGPoint(x: 2, y: 2))
    }

    @Test func focusBeforeFirstClusterUsesUpcomingOne() {
        let clusters = [FocusCluster(start: 3, center: CGPoint(x: 7, y: 7))]
        #expect(FocusPlanner.focus(at: 1, in: clusters) == CGPoint(x: 7, y: 7))
    }

    @Test func clusterSpanIsHalfOfVisibleArea() {
        let span = FocusPlanner.clusterSpan(sourceSize: CGSize(width: 2000, height: 1000), scale: 2)
        #expect(span == CGSize(width: 500, height: 250))
    }
}
