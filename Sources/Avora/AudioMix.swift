import AVFoundation

/// The audio files of one raw recording and where each starts, in seconds after the first video frame.
struct AudioManifest: Codable {
    enum Kind: String, Codable { case microphone, system }

    struct Track: Codable {
        var file: String
        var kind: Kind
        var offset: Double
    }

    var tracks: [Track]
}

/// Which part of an audio file lands where on the video timeline.
struct AudioPlacement: Equatable {
    var sourceStart: Double
    var insertAt: Double
    var duration: Double

    init?(offset: Double, trackDuration: Double, videoDuration: Double) {
        sourceStart = max(-offset, 0)
        insertAt = max(offset, 0)
        duration = min(trackDuration - sourceStart, videoDuration - insertAt)
        guard duration > 0 else { return nil }
    }
}

enum AudioLevels {
    /// Microphone peaks are brought to −6 dBFS.
    static let target = pow(10, -6.0 / 20)
    /// +20 dB at most, so a nearly silent mic does not turn into loud hiss.
    static let maxGain = 10.0

    static func normalizingGain(peak: Double) -> Double {
        guard peak > 1e-6 else { return 1 }
        return min(target / peak, maxGain)
    }

    /// Mixer volumes stay at or below 1, so a mic boost is applied to the whole mix
    /// and system audio is turned down by the same amount first.
    static func mix(micGain: Double) -> (micVolume: Double, systemVolume: Double, outputGain: Double) {
        let output = max(micGain, 1)
        return (micGain / output, 1 / output, output)
    }
}

/// Mixes a recording's audio files into one stereo stream on the video's timeline.
final class AudioMixSource {
    static let sampleRate = 48_000.0

    private let reader: AVAssetReader
    private let output: AVAssetReaderAudioMixOutput
    private let gain: Float

    private init(reader: AVAssetReader, output: AVAssetReaderAudioMixOutput, gain: Float) {
        self.reader = reader
        self.output = output
        self.gain = gain
    }

    /// nil when the recording has no audio.
    static func make(for folder: RecordingFolder, duration: Double) async throws -> AudioMixSource? {
        let composition = AVMutableComposition()
        guard let audio = try await addAudio(from: folder, duration: duration, to: composition) else { return nil }
        let reader = try AVAssetReader(asset: composition)
        reader.timeRange = CMTimeRange(start: .zero, duration: .seconds(duration))
        let output = AVAssetReaderAudioMixOutput(audioTracks: audio.tracks, audioSettings: pcmSettings)
        output.audioMix = audio.mix
        reader.add(output)
        guard reader.startReading() else { throw ExportError.reader(reader.error) }
        return AudioMixSource(reader: reader, output: output, gain: Float(audio.outputGain))
    }

    /// Places a recording's audio files on `composition` and returns the mix that balances them.
    /// Mixer volumes cannot exceed 1, so a mic boost comes back as `outputGain` for the caller to apply.
    static func addAudio(from folder: RecordingFolder, duration: Double, to composition: AVMutableComposition) async throws
        -> (tracks: [AVMutableCompositionTrack], mix: AVMutableAudioMix, outputGain: Double)? {
        guard let data = try? Data(contentsOf: folder.audioManifest) else { return nil }
        let manifest = try JSONDecoder().decode(AudioManifest.self, from: data)

        var placed: [(track: AVMutableCompositionTrack, kind: AudioManifest.Kind, url: URL)] = []
        for entry in manifest.tracks {
            let url = folder.url.appending(path: entry.file)
            let asset = AVURLAsset(url: url)
            guard let source = try await asset.loadTracks(withMediaType: .audio).first,
                  let placement = AudioPlacement(offset: entry.offset, trackDuration: try await asset.load(.duration).seconds,
                                                 videoDuration: duration),
                  let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { continue }
            try track.insertTimeRange(
                CMTimeRange(start: .seconds(placement.sourceStart), duration: .seconds(placement.duration)),
                of: source, at: .seconds(placement.insertAt)
            )
            placed.append((track, entry.kind, url))
        }
        guard !placed.isEmpty else { return nil }

        var micGain = 1.0
        if let mic = placed.first(where: { $0.kind == .microphone }) {
            micGain = AudioLevels.normalizingGain(peak: try await peak(of: mic.url))
        }
        let levels = AudioLevels.mix(micGain: micGain)
        let mix = AVMutableAudioMix()
        mix.inputParameters = placed.map { entry in
            let parameters = AVMutableAudioMixInputParameters(track: entry.track)
            parameters.setVolume(Float(entry.kind == .microphone ? levels.micVolume : levels.systemVolume), at: .zero)
            return parameters
        }
        return (placed.map(\.track), mix, levels.outputGain)
    }

    /// The loudest moment in each of `buckets` equal slices of the exported mix, from 0 to 1.
    /// nil when the recording has no audio.
    static func waveform(for folder: RecordingFolder, duration: Double, buckets: Int) async throws -> [Float]? {
        guard buckets > 0, let source = try await make(for: folder, duration: duration) else { return nil }
        defer { source.cancel() }
        var peaks = [Float](repeating: 0, count: buckets)
        let framesPerBucket = max(duration * sampleRate / Double(buckets), 1)
        while let buffer = source.nextBuffer() {
            let first = buffer.presentationTimeStamp.seconds * sampleRate
            var sample = 0
            forEachSample(in: buffer) { value in
                // Two interleaved channels per frame.
                let bucket = min(max(Int((first + Double(sample / 2)) / framesPerBucket), 0), buckets - 1)
                peaks[bucket] = max(peaks[bucket], abs(value.pointee))
                sample += 1
            }
        }
        return peaks
    }

    func nextBuffer() -> CMSampleBuffer? {
        guard let buffer = output.copyNextSampleBuffer() else { return nil }
        if gain != 1 { Self.amplify(buffer, by: gain) }
        return buffer
    }

    func cancel() {
        reader.cancelReading()
    }

    private static let pcmSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsNonInterleaved: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    /// Loudest sample in a file, from 0 to 1.
    private static func peak(of url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return 0 }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: pcmSettings)
        reader.add(output)
        guard reader.startReading() else { throw ExportError.reader(reader.error) }
        var peak: Float = 0
        while let buffer = output.copyNextSampleBuffer() {
            forEachSample(in: buffer) { peak = max(peak, abs($0.pointee)) }
        }
        return Double(peak)
    }

    /// Reader buffers are private copies, so they can be changed in place.
    private static func amplify(_ buffer: CMSampleBuffer, by gain: Float) {
        forEachSample(in: buffer) { $0.pointee = min(max($0.pointee * gain, -1), 1) }
    }

    private static func forEachSample(in buffer: CMSampleBuffer, _ body: (UnsafeMutablePointer<Float>) -> Void) {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { return }
        var length = 0
        var pointer: UnsafeMutablePointer<CChar>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
              CMBlockBufferIsRangeContiguous(block, atOffset: 0, length: length),
              let pointer
        else { return }
        pointer.withMemoryRebound(to: Float.self, capacity: length / 4) { samples in
            for index in 0..<(length / 4) { body(samples + index) }
        }
    }
}

extension CMTime {
    static func seconds(_ value: Double) -> CMTime { CMTime(seconds: value, preferredTimescale: 48_000) }
}
