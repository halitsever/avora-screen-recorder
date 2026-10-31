import Testing
@testable import ZoomEngine

struct ZoomSegmentsTests {
    let config = ZoomConfig()

    @Test func singleClickOpensSegmentAroundIt() throws {
        let segments = ZoomSegments.make(clickTimes: [5.0], duration: 20, config: config)
        try #require(segments.count == 1)
        #expect(abs(segments[0].start - 4.7) < 1e-9)
        #expect(abs(segments[0].end - 7.5) < 1e-9)
    }

    @Test func clicksCloserThanMergeGapShareOneSegment() throws {
        let segments = ZoomSegments.make(clickTimes: [5.0, 9.0], duration: 30, config: config)
        try #require(segments.count == 1)
        #expect(abs(segments[0].start - 4.7) < 1e-9)
        #expect(abs(segments[0].end - 11.5) < 1e-9)
    }

    @Test func distantClicksGetSeparateSegments() throws {
        let segments = ZoomSegments.make(clickTimes: [2.0, 15.0], duration: 30, config: config)
        try #require(segments.count == 2)
        #expect(abs(segments[1].start - 14.7) < 1e-9)
    }

    @Test func clickInLastSecondIsIgnored() {
        let segments = ZoomSegments.make(clickTimes: [3.0, 19.5], duration: 20, config: config)
        #expect(segments.count == 1)
    }

    @Test func segmentEndStaysClearOfRecordingEnd() throws {
        let segments = ZoomSegments.make(clickTimes: [18.0], duration: 20, config: config)
        let segment = try #require(segments.first)
        #expect(abs(segment.end - 19.2) < 1e-9)
    }

    @Test func segmentStartNeverGoesNegative() throws {
        let segments = ZoomSegments.make(clickTimes: [0.1], duration: 20, config: config)
        let segment = try #require(segments.first)
        #expect(segment.start == 0)
    }

    @Test func unsortedClicksAreHandled() {
        let segments = ZoomSegments.make(clickTimes: [15.0, 2.0], duration: 30, config: config)
        #expect(segments.map { ($0.start * 10).rounded() / 10 } == [1.7, 14.7])
    }

    @Test func segmentsCarryConfiguredScale() throws {
        let segments = ZoomSegments.make(clickTimes: [5.0], duration: 20, config: ZoomConfig(scale: 2.5))
        let segment = try #require(segments.first)
        #expect(segment.scale == 2.5)
    }
}
