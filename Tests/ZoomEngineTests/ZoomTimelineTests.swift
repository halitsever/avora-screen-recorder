import CoreGraphics
import Foundation
import Testing
@testable import ZoomEngine

struct ZoomTimelineTests {
    private func timeline(_ ranges: [(Double, Double)], duration: Double = 20) -> ZoomTimeline {
        ZoomTimeline(segments: ranges.map { ZoomSegment(start: $0.0, end: $0.1, scale: 2) }, duration: duration)
    }

    private func ranges(_ timeline: ZoomTimeline) -> [[Double]] {
        timeline.segments.map { [$0.start, $0.end] }
    }

    @Test func segmentsAreSortedAndKeptInsideTheVideo() {
        let t = timeline([(12, 25), (2, 4)], duration: 20)
        #expect(ranges(t) == [[2, 4], [12, 20]])
    }

    @Test func movingKeepsTheLengthAndStopsAtNeighbours() {
        var t = timeline([(2, 4), (6, 9), (12, 14)])
        t.move(1, to: 3)
        #expect(ranges(t)[1] == [4, 7])
        t.move(1, to: 11)
        #expect(ranges(t)[1] == [9, 12])
    }

    @Test func movingStopsAtTheVideoEdges() {
        var t = timeline([(6, 9)], duration: 10)
        t.move(0, to: -2)
        #expect(ranges(t) == [[0, 3]])
        t.move(0, to: 9)
        #expect(ranges(t) == [[7, 10]])
    }

    @Test func resizingStopsAtNeighboursAndTheMinimumLength() {
        var t = timeline([(2, 4), (6, 9), (12, 14)])
        t.setStart(1, to: 1)
        #expect(ranges(t)[1] == [4, 9])
        t.setEnd(1, to: 13)
        #expect(ranges(t)[1] == [4, 12])
        t.setEnd(1, to: 3)
        #expect(ranges(t)[1] == [4, 4 + ZoomTimeline.minimumLength])
    }

    @Test func addingPlacesAThreeSecondZoomAtTheTime() throws {
        var t = timeline([(2, 4)])
        let added = t.add(at: 10, scale: 1.5)
        let index = try #require(added)
        #expect(ranges(t)[index] == [10, 13])
        #expect(t.segments[index].scale == 1.5)
    }

    @Test func addingNearANeighbourFillsWhatFits() throws {
        var t = timeline([(2, 4), (6, 9)])
        let added = t.add(at: 5, scale: 2)
        let index = try #require(added)
        #expect(ranges(t)[index] == [4, 6])
        #expect(ranges(t) == [[2, 4], [4, 6], [6, 9]])
    }

    @Test func addingInsideAZoomDoesNothing() {
        var t = timeline([(2, 4)])
        #expect(t.add(at: 3, scale: 2) == nil)
        #expect(t.segments.count == 1)
    }

    @Test func removingDropsOneZoom() {
        var t = timeline([(2, 4), (6, 9)])
        t.remove(0)
        #expect(ranges(t) == [[6, 9]])
    }

    @Test func indexAtTimeFindsTheZoomUnderThePlayhead() {
        let t = timeline([(2, 4), (6, 9)])
        #expect(t.index(at: 7) == 1)
        #expect(t.index(at: 5) == nil)
    }

    @Test func editsSurviveAJSONRoundTrip() throws {
        var segment = ZoomSegment(start: 1, end: 3, scale: 2.5)
        segment.focus = CGPoint(x: 0.25, y: 0.75)
        let decoded = try JSONDecoder().decode(ZoomSegment.self, from: JSONEncoder().encode(segment))
        #expect(decoded == segment)
    }
}

struct ManualFocusTests {
    @Test func manualFocusHoldsTheCameraOnThePoint() {
        let log = InputLog(
            sourceSize: CGSize(width: 1000, height: 600), pointPixelScale: 1, duration: 4,
            cursor: [CursorSample(time: 0, position: CGPoint(x: 900, y: 500))],
            clicks: [ClickEvent(time: 1, position: CGPoint(x: 900, y: 500), isDown: true)]
        )
        let base = CGRect(x: 0, y: 0, width: 1000, height: 600)
        var manual = ZoomSegment(start: 0.5, end: 3.5, scale: 2)
        manual.focus = CGPoint(x: 0.5, y: 0.5)
        let frames = Director(log: log, base: base, segments: [manual]).frames(fps: 10)
        let expected = Framing.zoomedRect(base: base, scale: 2, focus01: CGPoint(x: 0.5, y: 0.5))
        #expect(abs(frames[30].screenRect.midX - expected.midX) < 1)
        #expect(abs(frames[30].screenRect.width - expected.width) < 1)
    }

    @Test func givenSegmentsReplaceTheClickZooms() {
        let log = InputLog(
            sourceSize: CGSize(width: 1000, height: 600), pointPixelScale: 1, duration: 4,
            cursor: [CursorSample(time: 0, position: CGPoint(x: 500, y: 300))],
            clicks: [ClickEvent(time: 1, position: CGPoint(x: 500, y: 300), isDown: true)]
        )
        let base = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let frames = Director(log: log, base: base, segments: []).frames(fps: 10)
        #expect(frames.allSatisfy { $0.screenRect == base })
    }
}
