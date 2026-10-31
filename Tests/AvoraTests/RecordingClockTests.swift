import Testing
@testable import Avora

struct RecordingClockTests {
    @Test func withoutPausesRecordingTimeIsHostTime() {
        let clock = RecordingClock()
        #expect(clock.recordingTime(forHost: 12.5) == 12.5)
    }

    @Test func samplesDuringAPauseAreDropped() {
        let clock = RecordingClock()
        clock.pause(at: 10)
        #expect(clock.recordingTime(forHost: 11) == nil)
        clock.resume(at: 14)
        #expect(clock.recordingTime(forHost: 12) == nil)
    }

    @Test func timeAfterAPauseIsShiftedBack() {
        let clock = RecordingClock()
        clock.pause(at: 10)
        clock.resume(at: 14)
        #expect(clock.recordingTime(forHost: 9) == 9)
        #expect(clock.recordingTime(forHost: 15) == 11)
    }

    @Test func pausesAddUp() {
        let clock = RecordingClock()
        clock.pause(at: 10)
        clock.resume(at: 12)
        clock.pause(at: 20)
        clock.resume(at: 25)
        #expect(clock.recordingTime(forHost: 30) == 23)
        #expect(clock.pausedDuration == 7)
    }

    @Test func pausingTwiceKeepsTheFirstStart() {
        let clock = RecordingClock()
        clock.pause(at: 10)
        clock.pause(at: 11)
        clock.resume(at: 13)
        #expect(clock.recordingTime(forHost: 13) == 10)
    }

    @Test func stoppingWhilePausedEndsAtThePause() {
        let clock = RecordingClock()
        clock.pause(at: 10)
        #expect(clock.recordingTime(endingAt: 18) == 10)
    }
}
