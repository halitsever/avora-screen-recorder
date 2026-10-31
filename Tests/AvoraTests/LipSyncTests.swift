import Foundation
import Testing
@testable import Avora

struct LipSyncTests {
    /// Syllables of varying length and loudness with pauses between them, sampled every `LipSync.step`.
    private func speech(seconds: Double, seed: UInt64 = 7) -> [Double] {
        var state = seed
        func random() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
        var samples: [Double] = []
        let count = Int(seconds / LipSync.step)
        while samples.count < count {
            let syllable = Int((0.1 + random() * 0.15) / LipSync.step), pause = Int((0.05 + random() * 0.25) / LipSync.step)
            let loudness = 0.5 + random() * 0.5
            samples += (0..<syllable).map { loudness * sin(Double.pi * Double($0) / Double(syllable)) }
            samples += Array(repeating: 0, count: pause)
        }
        return Array(samples.prefix(count))
    }

    /// What the camera sees: the same shape `delay` seconds later, held for each 30 fps frame.
    private func mouth(following voice: [Double], delay: Double) -> [Double?] {
        let shift = Int((delay / LipSync.step).rounded())
        let frame = Int((1.0 / 30) / LipSync.step)
        return voice.indices.map { index in
            let held = (index - shift) / frame * frame
            return held >= 0 && held < voice.count ? 0.2 + voice[held] * 0.4 : 0.2
        }
    }

    @Test func findsHowLateTheCameraRuns() throws {
        let voice = speech(seconds: 20)
        let lag = try #require(LipSync.lag(mouth: mouth(following: voice, delay: 0.12), voice: voice))
        #expect(abs(lag - 0.12) < 0.02)
    }

    @Test func findsACameraThatRunsEarly() throws {
        let voice = speech(seconds: 20)
        let lag = try #require(LipSync.lag(mouth: mouth(following: voice, delay: -0.08), voice: voice))
        #expect(abs(lag + 0.08) < 0.02)
    }

    @Test func framesWithoutAFaceAreSkipped() throws {
        let voice = speech(seconds: 20)
        var seen = mouth(following: voice, delay: 0.1)
        for index in stride(from: 0, to: seen.count, by: 400) { seen.replaceSubrange(index..<min(index + 100, seen.count), with: repeatElement(nil, count: min(100, seen.count - index))) }
        let lag = try #require(LipSync.lag(mouth: seen, voice: voice))
        #expect(abs(lag - 0.1) < 0.02)
    }

    @Test func unrelatedMovementChangesNothing() {
        let voice = speech(seconds: 20)
        let other = speech(seconds: 20, seed: 99).map { Optional(0.2 + $0 * 0.4) }
        #expect(LipSync.lag(mouth: other, voice: voice) == nil)
    }

    @Test func busiestWindowFollowsTheTalking() {
        let quiet = [Double](repeating: 0, count: 2000)
        let voice = quiet + speech(seconds: 10) + quiet
        let window = LipSync.busiestWindow(voice, length: 2000)
        #expect(window.lowerBound >= 1800 && window.upperBound <= 4200)
    }

    @Test func correctionMovesWhereTheCameraIsPlaced() {
        let manifest = CameraManifest(file: "camera.mov", offset: 0.5, sync: 0.12)
        #expect(abs(manifest.syncedOffset - 0.38) < 1e-9)
        #expect(CameraManifest(file: "camera.mov", offset: 0.5).syncedOffset == 0.5)
    }
}
