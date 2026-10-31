import AVFoundation
import Foundation
import Testing
@testable import Avora

private func toneFile(seconds: Double) async throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "avora-voice-\(UUID().uuidString).m4a")
    let writer = AudioTrackWriter(url: url)
    for step in 0..<Int(seconds * 100) { writer.append(try toneBuffer(at: Double(step) / 100)) }
    _ = await writer.finish()
    return url
}

struct VoiceProcessingTests {
    @Test func standardAndOffUseTheRecordingAsIs() async throws {
        let url = try await toneFile(seconds: 1)
        #expect(try VoiceProcessor.processed(url, preset: .standard) == url)
        #expect(try VoiceProcessor.processed(url, preset: .off) == url)
    }

    @Test func clearVoiceKeepsTheLength() async throws {
        let url = try await toneFile(seconds: 2)
        let processed = try VoiceProcessor.processed(url, preset: .clear)
        #expect(processed != url)
        let original = try await AVURLAsset(url: url).load(.duration).seconds
        let cleaned = try await AVURLAsset(url: processed).load(.duration).seconds
        #expect(abs(cleaned - original) < 0.05)
    }

    @Test func processedVoiceIsReusedNextTime() async throws {
        let url = try await toneFile(seconds: 1)
        let first = try VoiceProcessor.processed(url, preset: .clear)
        let made = try FileManager.default.attributesOfItem(atPath: first.path)[.modificationDate] as? Date
        let second = try VoiceProcessor.processed(url, preset: .clear)
        #expect(second == first)
        #expect(try FileManager.default.attributesOfItem(atPath: second.path)[.modificationDate] as? Date == made)
    }

    @Test func onlyOffSkipsLeveling() {
        #expect(!VoicePreset.off.normalizes)
        #expect(VoicePreset.standard.normalizes && VoicePreset.clear.normalizes)
    }
}
