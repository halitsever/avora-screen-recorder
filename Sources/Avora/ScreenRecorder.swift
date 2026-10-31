import AVFoundation
import ScreenCaptureKit

struct CaptureTarget {
    let filter: SCContentFilter
    /// Global points, top-left origin.
    let bounds: CGRect
    let scale: Double
    let pixelSize: CGSize

    /// The display under the mouse, with this app's own windows left out.
    static func current() async throws -> CaptureTarget {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let mouse = CGEvent(source: nil)?.location ?? .zero
        guard let display = content.displays.first(where: { CGDisplayBounds($0.displayID).contains(mouse) })
            ?? content.displays.first
        else { throw RecorderError.noDisplay }

        let ownApp = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
        let bounds = CGDisplayBounds(display.displayID)
        let scale = Double(filter.pointPixelScale)
        let pixelSize = CGSize(width: even(bounds.width * scale), height: even(bounds.height * scale))
        return CaptureTarget(filter: filter, bounds: bounds, scale: scale, pixelSize: pixelSize)
    }

    private static func even(_ value: Double) -> Double {
        (value / 2).rounded(.down) * 2
    }
}

enum RecorderError: LocalizedError {
    case noDisplay
    case noFrames
    case writer(Error?)

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display is available to record."
        case .noFrames: "The recording did not capture any frames."
        case .writer(let error): "Could not write the recording: \(error?.localizedDescription ?? "unknown error")"
        }
    }
}

/// Captures one display without the cursor and writes it to a movie file.
final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "avora.capture", qos: .userInteractive)
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var firstFrameTime: CMTime?
    private var lastFrameTime: CMTime?

    static let fps: Int32 = 60

    func start(_ target: CaptureTarget, to url: URL) async throws {
        let config = SCStreamConfiguration()
        config.width = Int(target.pixelSize.width)
        config.height = Int(target.pixelSize.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: Self.fps)
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        config.colorSpaceName = CGColorSpace.sRGB
        config.queueDepth = 6

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: Self.videoSettings(for: target.pixelSize))
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        self.writer = writer
        self.input = input

        let stream = SCStream(filter: target.filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    /// Returns host times of the first frame and of the moment capture stopped.
    func stop() async throws -> (start: Double, end: Double) {
        try await stream?.stopCapture()
        stream = nil
        let end = CMClockGetTime(CMClockGetHostTimeClock())

        let (writer, input, first, last) = queue.sync { (self.writer, self.input, firstFrameTime, lastFrameTime) }
        guard let writer, let input, let first, let last else { throw RecorderError.noFrames }

        input.markAsFinished()
        writer.endSession(atSourceTime: CMTimeMaximum(end, last))
        await writer.finishWriting()
        if writer.status != .completed { throw RecorderError.writer(writer.error) }
        return (first.seconds, CMTimeMaximum(end, last).seconds)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid, Self.isCompleteFrame(buffer), let writer, let input else { return }
        let time = buffer.presentationTimeStamp
        if firstFrameTime == nil {
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: time)
            firstFrameTime = time
        }
        guard writer.status == .writing, input.isReadyForMoreMediaData else { return }
        if input.append(buffer) { lastFrameTime = time }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("Avora: capture stopped with error: \(error.localizedDescription)")
    }

    /// ScreenCaptureKit also sends idle and blank buffers that carry no image.
    private static func isCompleteFrame(_ buffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]],
            let raw = attachments.first?[.status] as? Int
        else { return false }
        return SCFrameStatus(rawValue: raw) == .complete
    }

    private static func videoSettings(for size: CGSize) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                // Generous bitrate: this file is an intermediate that gets zoomed into later.
                AVVideoAverageBitRateKey: Int(size.width * size.height * 10),
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoAllowFrameReorderingKey: false,
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
    }
}
