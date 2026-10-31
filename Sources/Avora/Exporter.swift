import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import ZoomEngine

enum ExportError: LocalizedError {
    case noVideoTrack
    case reader(Error?)
    case writer(Error?)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: "The recording has no video track."
        case .reader(let error): "Could not read the recording: \(error?.localizedDescription ?? "unknown error")"
        case .writer(let error): "Could not write the video: \(error?.localizedDescription ?? "unknown error")"
        }
    }
}

extension RenderSettings.Format {
    var fileExtension: String {
        switch self {
        case .h264, .hevc: "mp4"
        case .prores: "mov"
        case .gif: "gif"
        }
    }
}

/// Renders a raw recording into the final styled, auto-zoomed movie.
/// Frames are produced on a fixed clock because screen capture skips frames while
/// nothing changes, yet the camera can still be moving then.
enum Exporter {
    static func export(
        _ folder: RecordingFolder,
        to output: URL,
        style: OutputStyle = OutputStyle(),
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws {
        let log = try JSONDecoder().decode(InputLog.self, from: Data(contentsOf: folder.log))
        let renderer = FrameRenderer(log: log, cursorFolder: folder.cursors, style: style, segments: folder.loadEdits())
        let asset = AVURLAsset(url: folder.video)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ExportError.noVideoTrack }

        let reader = try AVAssetReader(asset: asset)
        let source = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        source.alwaysCopiesSampleData = false
        reader.add(source)
        guard reader.startReading() else { throw ExportError.reader(reader.error) }
        defer { reader.cancelReading() }

        try? FileManager.default.removeItem(at: output)
        let sink: FrameSink = style.format == .gif
            ? try GIFSink(url: output, size: renderer.canvas, fps: style.fps)
            : try MovieSink(url: output, size: renderer.canvas, style: style,
                            audio: try await AudioMixSource.make(for: folder, duration: log.duration))

        let frameCount = max(Int(log.duration * style.fps), 1)
        var current: CMSampleBuffer?
        var upcoming = source.copyNextSampleBuffer()

        for index in 0..<frameCount {
            try Task.checkCancellation()
            let time = Double(index) / style.fps

            // Hold the newest source frame that has started by `time`.
            while let next = upcoming, next.presentationTimeStamp.seconds <= time + 0.0005 {
                current = next
                upcoming = source.copyNextSampleBuffer()
            }
            guard let frame = (current ?? upcoming).flatMap(CMSampleBufferGetImageBuffer) else { continue }

            try await sink.append(renderer.render(source: CIImage(cvPixelBuffer: frame), at: time), index: index)
            if index % 15 == 0 { progress(Double(index) / Double(frameCount)) }
        }

        try await sink.finish()
        progress(1)
    }
}

private protocol FrameSink {
    func append(_ image: CIImage, index: Int) async throws
    func finish() async throws
}

private final class MovieSink: FrameSink {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let audioDone = DispatchGroup()
    private let size: CGSize
    private let fps: Double
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    init(url: URL, size: CGSize, style: OutputStyle, audio: AudioMixSource?) throws {
        self.size = size
        fps = style.fps
        writer = try AVAssetWriter(outputURL: url, fileType: style.format == .prores ? .mov : .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: Self.settings(size: size, style: style))
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ])
        writer.add(input)

        var audioInput: AVAssetWriterInput?
        if audio != nil {
            let settings = style.format == .prores ? Self.pcmAudioSettings : Self.aacAudioSettings
            let added = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
            writer.add(added)
            audioInput = added
        }
        guard writer.startWriting() else { throw ExportError.writer(writer.error) }
        writer.startSession(atSourceTime: .zero)
        if let audio, let audioInput { pump(audio, into: audioInput) }
    }

    /// Audio is written alongside the video so the writer can interleave the two.
    private func pump(_ audio: AudioMixSource, into input: AVAssetWriterInput) {
        audioDone.enter()
        let queue = DispatchQueue(label: "avora.export.audio")
        nonisolated(unsafe) var finished = false
        input.requestMediaDataWhenReady(on: queue) { [audioDone] in
            while !finished, input.isReadyForMoreMediaData {
                guard let buffer = audio.nextBuffer(), input.append(buffer) else {
                    finished = true
                    input.markAsFinished()
                    audio.cancel()
                    audioDone.leave()
                    return
                }
            }
        }
    }

    func append(_ image: CIImage, index: Int) async throws {
        while !input.isReadyForMoreMediaData {
            if writer.status == .failed { throw ExportError.writer(writer.error) }
            try await Task.sleep(for: .milliseconds(2))
        }
        guard let pool = adaptor.pixelBufferPool else { throw ExportError.writer(writer.error) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { throw ExportError.writer(writer.error) }
        context.render(image, to: buffer, bounds: CGRect(origin: .zero, size: size), colorSpace: colorSpace)
        let stamp = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(fps))
        guard adaptor.append(buffer, withPresentationTime: stamp) else { throw ExportError.writer(writer.error) }
    }

    func finish() async throws {
        input.markAsFinished()
        await withCheckedContinuation { done in audioDone.notify(queue: .global()) { done.resume() } }
        await writer.finishWriting()
        guard writer.status == .completed else { throw ExportError.writer(writer.error) }
    }

    private static var stereoLayout: Data {
        var layout = AudioChannelLayout()
        layout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        return Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)
    }

    private static var aacAudioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: AudioMixSource.sampleRate,
            AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: stereoLayout,
            AVEncoderBitRateKey: 192_000,
        ]
    }

    private static var pcmAudioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: AudioMixSource.sampleRate,
            AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: stereoLayout,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
    }

    private static func settings(size: CGSize, style: OutputStyle) -> [String: Any] {
        var settings: [String: Any] = [
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        switch style.format {
        case .prores:
            settings[AVVideoCodecKey] = AVVideoCodecType.proRes422HQ
        case .hevc:
            settings[AVVideoCodecKey] = AVVideoCodecType.hevc
            settings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: RenderSettings.bitrate(for: size, fps: style.fps, format: .hevc, quality: style.quality),
                AVVideoExpectedSourceFrameRateKey: style.fps,
            ]
        case .h264, .gif:
            settings[AVVideoCodecKey] = AVVideoCodecType.h264
            settings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: RenderSettings.bitrate(for: size, fps: style.fps, format: .h264, quality: style.quality),
                AVVideoExpectedSourceFrameRateKey: style.fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ]
        }
        return settings
    }
}

/// GIF frames are quantized by ImageIO; the delay is rounded to whole hundredths by the format.
private final class GIFSink: FrameSink {
    private let destination: CGImageDestination
    private let frameProperties: CFDictionary
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let size: CGSize

    init(url: URL, size: CGSize, fps: Double) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, .max, nil) else {
            throw ExportError.writer(nil)
        }
        self.destination = destination
        self.size = size
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ] as CFDictionary)
        frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
    }

    func append(_ image: CIImage, index: Int) async throws {
        guard let frame = context.createCGImage(image, from: CGRect(origin: .zero, size: size)) else { throw ExportError.writer(nil) }
        CGImageDestinationAddImage(destination, frame, frameProperties)
    }

    func finish() async throws {
        guard CGImageDestinationFinalize(destination) else { throw ExportError.writer(nil) }
    }
}
