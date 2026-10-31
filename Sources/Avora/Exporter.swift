import AVFoundation
import CoreImage
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
        let renderer = FrameRenderer(log: log, cursorFolder: folder.cursors, style: style)
        let asset = AVURLAsset(url: folder.video)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ExportError.noVideoTrack }

        let reader = try AVAssetReader(asset: asset)
        let source = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        source.alwaysCopiesSampleData = false
        reader.add(source)

        try? FileManager.default.removeItem(at: output)
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings(for: renderer.canvas, fps: style.fps))
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(renderer.canvas.width),
            kCVPixelBufferHeightKey as String: Int(renderer.canvas.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ])
        writer.add(input)

        guard reader.startReading() else { throw ExportError.reader(reader.error) }
        guard writer.startWriting() else { throw ExportError.writer(writer.error) }
        writer.startSession(atSourceTime: .zero)

        let context = CIContext(options: [.cacheIntermediates: false])
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
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

            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw ExportError.writer(writer.error) }
                try await Task.sleep(for: .milliseconds(2))
            }
            guard let pool = adaptor.pixelBufferPool else { throw ExportError.writer(writer.error) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw ExportError.writer(writer.error) }

            let image = renderer.render(source: CIImage(cvPixelBuffer: frame), at: time)
            context.render(image, to: buffer, bounds: CGRect(origin: .zero, size: renderer.canvas), colorSpace: colorSpace)
            let stamp = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(style.fps))
            guard adaptor.append(buffer, withPresentationTime: stamp) else { throw ExportError.writer(writer.error) }

            if index % 15 == 0 { progress(Double(index) / Double(frameCount)) }
        }

        reader.cancelReading()
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ExportError.writer(writer.error) }
        progress(1)
    }

    private static func videoSettings(for size: CGSize, fps: Double) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(size.width * size.height * 4),
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
    }
}
