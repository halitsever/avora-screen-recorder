import AVFoundation
import ZoomEngine

/// A raw recording laid out on the video's timeline: clips cut, sped up and joined. Every
/// track is copied clip by clip so the screen and each audio source keep their own volume.
struct TimelineComposition {
    /// Keeps voices at their pitch when a clip is sped up or slowed down.
    static let pitchAlgorithm = AVAudioTimePitchAlgorithm.spectral

    let composition: AVMutableComposition
    let videoTrackID: CMPersistentTrackID?
    let cameraTrackID: CMPersistentTrackID?
    let audioTracks: [AVMutableCompositionTrack]
    let audioMix: AVMutableAudioMix?
    let audioGain: Double
    /// Seconds of video.
    let duration: Double

    static func make(for folder: RecordingFolder, sourceDuration: Double, clips: ClipList, video: Bool, voice: VoicePreset) async throws -> TimelineComposition {
        let source = AVMutableComposition()
        var sourceVideo: AVMutableCompositionTrack?
        if video {
            let asset = AVURLAsset(url: folder.video)
            guard let track = try await asset.loadTracks(withMediaType: .video).first,
                  let added = source.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { throw ExportError.noVideoTrack }
            let available = try await track.load(.timeRange)
            try added.insertTimeRange(CMTimeRange(start: available.start, duration: CMTimeMinimum(.seconds(sourceDuration), available.duration)),
                                      of: track, at: .zero)
            sourceVideo = added
        }
        var sourceCamera: AVMutableCompositionTrack?
        if video, let manifest = folder.loadCamera() {
            let asset = AVURLAsset(url: folder.url.appending(path: manifest.file))
            if let track = try await asset.loadTracks(withMediaType: .video).first,
               let placement = AudioPlacement(offset: manifest.syncedOffset, trackDuration: try await asset.load(.duration).seconds,
                                              videoDuration: sourceDuration),
               let added = source.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try added.insertTimeRange(CMTimeRange(start: .seconds(placement.sourceStart), duration: .seconds(placement.duration)),
                                          of: track, at: .seconds(placement.insertAt))
                sourceCamera = added
            }
        }
        let audio = try await AudioMixSource.addAudio(from: folder, duration: sourceDuration, to: source, voice: voice)

        let output = AVMutableComposition()
        var copies: [(from: AVMutableCompositionTrack, to: AVMutableCompositionTrack)] = []
        var videoOut: AVMutableCompositionTrack?
        if let sourceVideo, let track = output.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            copies.append((sourceVideo, track))
            videoOut = track
        }
        var cameraOut: AVMutableCompositionTrack?
        if let sourceCamera, let track = output.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            copies.append((sourceCamera, track))
            cameraOut = track
        }
        var audioOut: [(track: AVMutableCompositionTrack, volume: Float)] = []
        for entry in audio?.tracks ?? [] {
            guard let track = output.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
            copies.append((entry.track, track))
            audioOut.append((track, entry.volume))
        }

        var cursor = CMTime.zero
        for clip in clips.segments {
            let range = CMTimeRange(start: .seconds(clip.start), duration: .seconds(clip.length))
            for (from, to) in copies {
                // A source may start late or end early; empty time keeps every track aligned.
                let media = range.intersection(from.timeRange)
                if !media.isEmpty {
                    pad(to, until: CMTimeAdd(cursor, CMTimeSubtract(media.start, range.start)))
                    try to.insertTimeRange(media, of: from, at: CMTimeAdd(cursor, CMTimeSubtract(media.start, range.start)))
                }
                pad(to, until: CMTimeAdd(cursor, range.duration))
            }
            let length = CMTime.seconds(clip.outputLength)
            if clip.speed != 1 { output.scaleTimeRange(CMTimeRange(start: cursor, duration: range.duration), toDuration: length) }
            cursor = CMTimeAdd(cursor, length)
        }

        return TimelineComposition(
            composition: output,
            videoTrackID: videoOut?.trackID,
            cameraTrackID: cameraOut?.trackID,
            audioTracks: audioOut.map(\.track),
            audioMix: audioOut.isEmpty ? nil : AudioMixSource.mix(audioOut.map { ($0.track, $0.volume) }),
            audioGain: audio?.outputGain ?? 1,
            duration: clips.outputDuration
        )
    }

    private static func pad(_ track: AVMutableCompositionTrack, until time: CMTime) {
        let end = track.timeRange.end.isValid ? track.timeRange.end : .zero
        if end < time { track.insertEmptyTimeRange(CMTimeRange(start: end, end: time)) }
    }
}
