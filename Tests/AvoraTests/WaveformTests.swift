import Foundation
import Testing
@testable import Avora

struct WaveformTests {
    private func folder(withToneAt offset: Double) async throws -> RecordingFolder {
        let folder = RecordingFolder(url: FileManager.default.temporaryDirectory.appending(path: "avora-wave-\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let writer = AudioTrackWriter(url: folder.microphone)
        for step in 0..<100 { writer.append(try toneBuffer(at: Double(step) / 100)) }
        _ = await writer.finish()
        let manifest = AudioManifest(tracks: [.init(file: folder.microphone.lastPathComponent, kind: .microphone, offset: offset)])
        try JSONEncoder().encode(manifest).write(to: folder.audioManifest)
        return folder
    }

    @Test func waveformShowsWhereTheSoundIs() async throws {
        let folder = try await folder(withToneAt: 1)
        let peaks = try #require(try await AudioMixSource.waveform(for: folder, duration: 3, buckets: 3))
        #expect(peaks.count == 3)
        #expect(peaks[0] < 0.05)
        #expect(peaks[1] > 0.3)
        #expect(peaks[2] < 0.05)
    }

    @Test func recordingWithoutAudioHasNoWaveform() async throws {
        let folder = RecordingFolder(url: FileManager.default.temporaryDirectory.appending(path: "avora-silent-\(UUID().uuidString)"))
        #expect(try await AudioMixSource.waveform(for: folder, duration: 3, buckets: 3) == nil)
    }
}
