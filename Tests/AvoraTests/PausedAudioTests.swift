import AVFoundation
import Testing
@testable import Avora

/// 10 ms of a 48 kHz mono sine starting at `host` seconds.
func toneBuffer(at host: Double) throws -> CMSampleBuffer {
    let rate = 48_000.0, count = 480
    var description = AudioStreamBasicDescription(
        mSampleRate: rate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0
    )
    var format: CMAudioFormatDescription?
    CMAudioFormatDescriptionCreate(allocator: nil, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                   magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
    var samples = (0..<count).map { Float(sin(Double($0) / rate * 440 * 2 * .pi) * 0.5) }
    var block: CMBlockBuffer?
    CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: count * 4, blockAllocator: nil,
                                       customBlockSource: nil, offsetToData: 0, dataLength: count * 4, flags: 0, blockBufferOut: &block)
    CMBlockBufferReplaceDataBytes(with: &samples, blockBuffer: block!, offsetIntoDestination: 0, dataLength: count * 4)
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48_000),
                                    presentationTimeStamp: CMTime(seconds: host, preferredTimescale: 48_000),
                                    decodeTimeStamp: .invalid)
    var buffer: CMSampleBuffer?
    CMSampleBufferCreate(allocator: nil, dataBuffer: block, dataReady: true, makeDataReadyCallback: nil, refcon: nil,
                         formatDescription: format, sampleCount: count, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                         sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &buffer)
    return try #require(buffer)
}

struct PausedAudioTests {
    @Test func buffersAfterAPauseAreMovedBack() throws {
        let clock = RecordingClock()
        clock.pause(at: 10)
        clock.resume(at: 13)
        let moved = try #require(try toneBuffer(at: 14).onRecordingClock(clock))
        #expect(abs(moved.presentationTimeStamp.seconds - 11) < 1e-6)
    }

    @Test func buffersInsideAPauseAreDropped() throws {
        let clock = RecordingClock()
        clock.pause(at: 10)
        #expect(try toneBuffer(at: 10.5).onRecordingClock(clock) == nil)
    }

    @Test func pausedStretchIsMissingFromTheWrittenFile() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "avora-paused-\(UUID().uuidString).m4a")
        let clock = RecordingClock()
        let writer = AudioTrackWriter(url: url)
        // One second of sound, two seconds paused, one more second of sound.
        for step in 0..<400 {
            let host = 5 + Double(step) / 100
            if host == 6 { clock.pause(at: 6) }
            if host == 8 { clock.resume(at: 8) }
            if let moved = try toneBuffer(at: host).onRecordingClock(clock) { writer.append(moved) }
        }
        let start = try #require(await writer.finish())
        #expect(abs(start - 5) < 1e-6)

        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        #expect(abs(duration - 2) < 0.05)
    }
}
