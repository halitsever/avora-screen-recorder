import AVFoundation
import Vision

/// Lines the camera up with the microphone by watching the speaker's mouth: it opens and closes
/// with the loudness of the voice, so the delay where the two match best is the camera's lag.
enum LipSync {
    /// Seconds between samples of both series.
    static let step = 0.005
    static let maxLag = 0.35
    /// Seconds of talking looked at. Enough syllables to be sure, few enough frames to read quickly.
    static let window = 20.0

    /// How many seconds the mouth trails the voice, or nil when they don't clearly move together.
    /// Both series start at the same moment; nil marks a frame without a face.
    static func lag(mouth: [Double?], voice: [Double]) -> Double? {
        let voice = smoothed(voice, width: 8)
        let reach = Int((maxLag / step).rounded())
        var best: (shift: Int, score: Double)?
        for shift in -reach...reach {
            var n = 0.0, sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0
            for index in voice.indices {
                let other = index + shift
                guard other >= 0, other < mouth.count, let m = mouth[other] else { continue }
                let v = voice[index]
                n += 1; sx += v; sy += m; sxx += v * v; syy += m * m; sxy += v * m
            }
            guard n > Double(voice.count) / 3 else { continue }
            let spread = (sxx - sx * sx / n) * (syy - sy * sy / n)
            guard spread > 0 else { continue }
            let score = (sxy - sx * sy / n) / spread.squareRoot()
            if score > best?.score ?? -.infinity { best = (shift, score) }
        }
        // A best match at the edge of the search means the real lag lies beyond it.
        guard let best, best.score >= 0.3, abs(best.shift) < reach else { return nil }
        return Double(best.shift) * step
    }

    /// The `length` samples holding the most sound.
    static func busiestWindow(_ voice: [Double], length: Int) -> Range<Int> {
        guard voice.count > length else { return voice.indices }
        var sum = voice[..<length].reduce(0, +), best = (start: 0, sum: sum)
        for start in 1...(voice.count - length) {
            sum += voice[start + length - 1] - voice[start - 1]
            if sum > best.sum { best = (start, sum) }
        }
        return best.start..<(best.start + length)
    }

    /// Measures the camera's lag in a recording with a camera and a microphone.
    static func measure(_ folder: RecordingFolder) async -> Double? {
        guard let camera = folder.loadCamera(),
              let data = try? Data(contentsOf: folder.audioManifest),
              let track = (try? JSONDecoder().decode(AudioManifest.self, from: data))?.tracks.first(where: { $0.kind == .microphone }),
              let loudness = try? envelope(folder.url.appending(path: track.file))
        else { return nil }
        let span = busiestWindow(loudness, length: Int(window / step))
        // Times in the recording of the first and last voice samples looked at.
        let start = track.offset + Double(span.lowerBound) * step, end = track.offset + Double(span.upperBound) * step
        guard let frames = try? await mouthOpenings(folder.url.appending(path: camera.file),
                                                    from: start - camera.offset - 0.5, to: end - camera.offset + 0.5)
        else { return nil }
        var mouth: [Double?] = []
        var next = 0
        for index in span.indices {
            let local = track.offset + Double(index) * step - camera.offset
            while next < frames.count, frames[next].time <= local { next += 1 }
            let shown = next > 0 ? frames[next - 1] : nil
            mouth.append(shown.flatMap { local - $0.time < 0.1 ? $0.opening : nil })
        }
        return lag(mouth: mouth, voice: Array(loudness[span]))
    }

    /// Loudness of the first channel every `step` seconds.
    private static func envelope(_ url: URL) throws -> [Double] {
        let file = try AVAudioFile(forReading: url)
        let size = max(AVAudioFrameCount(file.processingFormat.sampleRate * step), 1)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: size * 400) else { return [] }
        var levels: [Double] = []
        while file.framePosition < file.length {
            try file.read(into: buffer)
            guard buffer.frameLength > 0, let samples = buffer.floatChannelData?[0] else { break }
            for start in stride(from: 0, to: Int(buffer.frameLength), by: Int(size)) {
                let count = min(Int(size), Int(buffer.frameLength) - start)
                var sum: Float = 0
                for index in start..<(start + count) { sum += samples[index] * samples[index] }
                levels.append(Double((sum / Float(count)).squareRoot()))
            }
        }
        return levels
    }

    /// How open the mouth is in each camera frame between two times of the camera file.
    private static func mouthOpenings(_ url: URL, from start: Double, to end: Double) async throws -> [(time: Double, opening: Double?)] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: .seconds(max(start, 0)), end: .seconds(max(end, 0)))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { throw ExportError.reader(reader.error) }
        var openings: [(time: Double, opening: Double?)] = []
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let pixels = CMSampleBufferGetImageBuffer(sample) else { continue }
            let request = VNDetectFaceLandmarksRequest()
            try VNImageRequestHandler(cvPixelBuffer: pixels).perform([request])
            let face = request.results?.max { $0.boundingBox.width < $1.boundingBox.width }
            // Inner lip points are fractions of the face box, so the gap reads the same near or far.
            let opening = face?.landmarks?.innerLips.map { lips in
                let heights = lips.normalizedPoints.map(\.y)
                return Double((heights.max() ?? 0) - (heights.min() ?? 0))
            }
            openings.append((sample.presentationTimeStamp.seconds, opening))
        }
        return openings
    }

    /// A moving average centered on each sample, so smoothing adds no delay of its own.
    private static func smoothed(_ values: [Double], width: Int) -> [Double] {
        guard values.count > width else { return values }
        var running = [0.0]
        for value in values { running.append(running.last! + value) }
        return values.indices.map { index in
            let low = max(index - width / 2, 0), high = min(index + width / 2 + 1, values.count)
            return (running[high] - running[low]) / Double(high - low)
        }
    }
}
