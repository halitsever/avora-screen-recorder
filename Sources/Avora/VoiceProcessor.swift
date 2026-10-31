import AVFoundation
import AudioToolbox

/// How the microphone is cleaned up on export.
enum VoicePreset: String, Codable, CaseIterable {
    /// The recording exactly as it was.
    case off
    /// Brought to a steady level.
    case standard
    /// Background noise removed by Apple's voice isolation, then evened out and limited.
    case clear

    /// Whether the voice's loudest moment is brought to the same level on every export.
    var normalizes: Bool { self != .off }
}

/// Runs a recorded voice through Apple's audio units, offline and on the Mac.
enum VoiceProcessor {
    /// The file to mix for `preset`. Processing runs once; the result sits next to the recording.
    static func processed(_ url: URL, preset: VoicePreset) throws -> URL {
        guard preset == .clear else { return url }
        let output = url.deletingPathExtension().appendingPathExtension("clear.caf")
        if FileManager.default.fileExists(atPath: output.path) { return output }
        try render(url, to: output)
        return output
    }

    private static func render(_ url: URL, to output: URL) throws {
        let input = try AVAudioFile(forReading: url)
        let format = input.processingFormat
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let units = [isolation(), effect(kAudioUnitSubType_DynamicsProcessor), effect(kAudioUnitSubType_PeakLimiter)]
        engine.attach(player)
        units.forEach(engine.attach)
        var previous: AVAudioNode = player
        for unit in units {
            engine.connect(previous, to: unit, format: format)
            previous = unit
        }
        engine.connect(previous, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try engine.start()
        player.scheduleFile(input, at: nil)
        player.play()

        // The units delay the sound a little; that many frames are skipped so voice and video stay in step.
        let latency = AVAudioFramePosition((units.reduce(0) { $0 + $1.latency } * format.sampleRate).rounded())
        let writer = try AVAudioFile(forWriting: output, settings: engine.manualRenderingFormat.settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount)
        else { throw ExportError.writer(nil) }
        var skipped: AVAudioFramePosition = 0
        while engine.manualRenderingSampleTime < input.length + latency {
            let remaining = input.length + latency - engine.manualRenderingSampleTime
            guard try engine.renderOffline(AVAudioFrameCount(min(remaining, AVAudioFramePosition(buffer.frameCapacity))), to: buffer) == .success
            else { break }
            let skip = min(latency - skipped, AVAudioFramePosition(buffer.frameLength))
            skipped += skip
            if skip < AVAudioFramePosition(buffer.frameLength) {
                try writer.write(from: skip == 0 ? buffer : buffer.dropping(AVAudioFrameCount(skip)))
            }
        }
        player.stop()
        engine.stop()
    }

    private static func isolation() -> AVAudioUnitEffect {
        let unit = effect(kAudioUnitSubType_AUSoundIsolation)
        let voice: Int = if #available(macOS 15, *) { kAUSoundIsolationSoundType_HighQualityVoice } else { kAUSoundIsolationSoundType_Voice }
        AudioUnitSetParameter(unit.audioUnit, AudioUnitParameterID(kAUSoundIsolationParam_SoundToIsolate), kAudioUnitScope_Global, 0, AudioUnitParameterValue(voice), 0)
        AudioUnitSetParameter(unit.audioUnit, AudioUnitParameterID(kAUSoundIsolationParam_WetDryMixPercent), kAudioUnitScope_Global, 0, 100, 0)
        return unit
    }

    private static func effect(_ subtype: OSType) -> AVAudioUnitEffect {
        AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect, componentSubType: subtype,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0
        ))
    }
}

private extension AVAudioPCMBuffer {
    /// The same audio without its first `frames` frames.
    func dropping(_ frames: AVAudioFrameCount) -> AVAudioPCMBuffer {
        let kept = frameLength - frames
        let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: kept)!
        copy.frameLength = kept
        for channel in 0..<Int(format.channelCount) {
            guard let from = floatChannelData?[channel], let to = copy.floatChannelData?[channel] else { continue }
            to.update(from: from + Int(frames), count: Int(kept))
        }
        return copy
    }
}
