import Testing
@testable import ZoomEngine

struct ClipListTests {
    private func clips(_ parts: [(Double, Double, Double)], duration: Double = 20) -> ClipList {
        ClipList(segments: parts.map { Clip(start: $0.0, end: $0.1, speed: $0.2) }, duration: duration)
    }

    @Test func untouchedRecordingIsOneClip() {
        let list = ClipList.whole(duration: 12)
        #expect(list.segments == [Clip(start: 0, end: 12, speed: 1)])
        #expect(list.outputDuration == 12)
    }

    @Test func cutsAndSpeedChangeTheOutputLength() {
        // 0-4 at normal speed, 6-10 at double speed: 4 + 2 seconds.
        #expect(clips([(0, 4, 1), (6, 10, 2)]).outputDuration == 6)
    }

    @Test func outputTimeMapsBackToTheRecording() {
        let list = clips([(0, 4, 1), (6, 10, 2)])
        #expect(list.sourceTime(atOutput: 3) == 3)
        #expect(list.sourceTime(atOutput: 4) == 6)
        #expect(list.sourceTime(atOutput: 5) == 8)
        #expect(list.sourceTime(atOutput: 99) == 10)
    }

    @Test func recordingTimeMapsToTheOutput() {
        let list = clips([(0, 4, 1), (6, 10, 2)])
        #expect(list.outputTime(atSource: 8) == 5)
        #expect(list.outputTime(atSource: 5) == nil)
        #expect(list.outputTime(snappingSource: 5) == 4)
    }

    @Test func splittingMakesTwoClipsWithTheSameSpeed() throws {
        var list = clips([(0, 10, 2)])
        let split = list.split(at: 4)
        let second = try #require(split)
        #expect(second == 1)
        #expect(list.segments == [Clip(start: 0, end: 4, speed: 2), Clip(start: 4, end: 10, speed: 2)])
    }

    @Test func splittingTooCloseToAnEdgeDoesNothing() {
        var list = clips([(0, 10, 1)])
        #expect(list.split(at: 0.05) == nil)
        #expect(list.split(at: 15) == nil)
        #expect(list.segments.count == 1)
    }

    @Test func removingAClipCutsItOut() {
        var list = clips([(0, 4, 1), (4, 10, 1)])
        list.remove(0)
        #expect(list.outputDuration == 6)
        #expect(list.sourceTime(atOutput: 0) == 4)
    }

    @Test func trimmingStopsAtNeighbours() {
        var list = clips([(0, 4, 1), (6, 10, 1)])
        list.setEnd(0, to: 8)
        #expect(list.segments[0].end == 6)
    }
}

struct TypingTests {
    @Test func steadyTypingIsABurst() {
        // Two seconds of typing at five keys a second, then a pause, then two stray keys.
        let times = stride(from: 3.0, through: 5.0, by: 0.2).map { $0 } + [9, 9.3]
        let bursts = TypingBursts.find(in: times)
        #expect(bursts.count == 1)
        #expect(abs(bursts[0].start - 3) < 1e-9 && abs(bursts[0].end - 5) < 1e-9)
    }

    @Test func shortOrSlowTypingIsLeftAlone() {
        #expect(TypingBursts.find(in: [1, 1.2, 1.4]).isEmpty)
        #expect(TypingBursts.find(in: stride(from: 0.0, through: 3.0, by: 0.6).map { $0 }).isEmpty)
    }

    @Test func speedingUpSplitsAroundEachBurst() {
        var clips = ClipList.whole(duration: 20)
        clips.speedUp([TimeRange(start: 5, end: 8)], to: 3)
        #expect(clips.segments == [Clip(start: 0, end: 5), Clip(start: 5, end: 8, speed: 3), Clip(start: 8, end: 20)])
        #expect(abs(clips.outputDuration - 18) < 1e-9)
    }

    @Test func speedingUpLeavesCutsAndOtherSpeedsAlone() {
        var clips = ClipList(segments: [Clip(start: 0, end: 4), Clip(start: 6, end: 10, speed: 2)], duration: 20)
        clips.speedUp([TimeRange(start: 3, end: 7)], to: 3)
        #expect(clips.segments == [Clip(start: 0, end: 3), Clip(start: 3, end: 4, speed: 3), Clip(start: 6, end: 10, speed: 2)])
    }
}
