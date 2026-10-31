import Testing
@testable import Avora

struct AudioMixTests {
    @Test func trackStartingAfterTheVideoIsDelayed() throws {
        let placement = try #require(AudioPlacement(offset: 0.25, trackDuration: 10, videoDuration: 8))
        #expect(placement.sourceStart == 0)
        #expect(placement.insertAt == 0.25)
        #expect(placement.duration == 7.75)
    }

    @Test func trackStartingBeforeTheVideoIsTrimmed() throws {
        let placement = try #require(AudioPlacement(offset: -0.5, trackDuration: 10, videoDuration: 8))
        #expect(placement.sourceStart == 0.5)
        #expect(placement.insertAt == 0)
        #expect(placement.duration == 8)
    }

    @Test func trackOutsideTheVideoIsSkipped() {
        #expect(AudioPlacement(offset: 9, trackDuration: 2, videoDuration: 8) == nil)
        #expect(AudioPlacement(offset: -3, trackDuration: 2, videoDuration: 8) == nil)
    }

    @Test func quietMicIsRaisedToMinusSixDecibels() {
        let gain = AudioLevels.normalizingGain(peak: 0.25)
        #expect(abs(gain * 0.25 - 0.501) < 0.001)
    }

    @Test func loudMicIsLowered() {
        #expect(AudioLevels.normalizingGain(peak: 1) < 1)
    }

    @Test func silenceIsLeftAlone() {
        #expect(AudioLevels.normalizingGain(peak: 0) == 1)
    }

    @Test func boostIsCappedSoHissDoesNotExplode() {
        #expect(AudioLevels.normalizingGain(peak: 0.001) == AudioLevels.maxGain)
    }

    @Test func boostingTheMicKeepsSystemAudioAtItsLevel() {
        let mix = AudioLevels.mix(micGain: 4)
        #expect(mix.micVolume * mix.outputGain == 4)
        #expect(mix.systemVolume * mix.outputGain == 1)
        #expect(mix.micVolume <= 1 && mix.systemVolume <= 1)
    }

    @Test func loweringTheMicNeedsNoOutputGain() {
        let mix = AudioLevels.mix(micGain: 0.5)
        #expect(mix.micVolume == 0.5)
        #expect(mix.systemVolume == 1)
        #expect(mix.outputGain == 1)
    }
}
