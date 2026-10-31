import AVFoundation
import ScreenCaptureKit

struct CaptureTarget {
    let filter: SCContentFilter
    /// What is recorded, in global points with a top-left origin.
    let bounds: CGRect
    /// The recorded part of the display in its own points; nil records the whole display.
    var sourceRect: CGRect?
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
        return CaptureTarget(filter: filter, bounds: bounds, sourceRect: nil, scale: scale, pixelSize: pixelSize)
    }

    /// A window's area or a dragged area, cropped from the display it overlaps most.
    static func area(_ area: CGRect) async throws -> CaptureTarget {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let frames = content.displays.map { CGDisplayBounds($0.displayID) }
        guard let index = CaptureGeometry.bestDisplay(for: area, among: frames) else { throw RecorderError.noDisplay }
        let bounds = area.intersection(frames[index])

        let ownApp = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: content.displays[index], excludingApplications: ownApp, exceptingWindows: [])
        let scale = Double(filter.pointPixelScale)
        return CaptureTarget(filter: filter, bounds: bounds, sourceRect: CaptureGeometry.sourceRect(for: bounds, on: frames[index]),
                             scale: scale, pixelSize: CaptureGeometry.pixelSize(for: bounds, scale: scale))
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

/// Captures one display without the cursor and writes it to a movie file. With `systemAudio`
/// it also records what the Mac plays, minus Avora's own sounds.
final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "avora.capture", qos: .userInteractive)
    private let audioQueue = DispatchQueue(label: "avora.capture.audio", qos: .userInteractive)
    private let clock: RecordingClock
    private let systemAudio: AudioTrackWriter?
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var firstFrameTime: CMTime?
    private var lastFrameTime: CMTime?
    /// The newest frame, kept through a pause so a static screen still shows its latest state on resume.
    private var latestFrame: CMSampleBuffer?

    static let fps: Int32 = 60

    init(clock: RecordingClock, systemAudio: AudioTrackWriter?) {
        self.clock = clock
        self.systemAudio = systemAudio
    }

    func start(_ target: CaptureTarget, to url: URL) async throws {
        let config = SCStreamConfiguration()
        config.width = Int(target.pixelSize.width)
        config.height = Int(target.pixelSize.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: Self.fps)
        config.showsCursor = false
        if let sourceRect = target.sourceRect { config.sourceRect = sourceRect }
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        config.colorSpaceName = CGColorSpace.sRGB
        config.queueDepth = 6
        if systemAudio != nil {
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.sampleRate = 48_000
            config.channelCount = 2
        }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: Self.videoSettings(for: target.pixelSize))
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        self.writer = writer
        self.input = input

        let stream = SCStream(filter: target.filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        if systemAudio != nil { try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue) }
        try await stream.startCapture()
        self.stream = stream
    }

    /// Repeats the newest frame at the resume point; capture only sends frames when the screen changes.
    func resumed() {
        queue.async { [self] in
            guard let latestFrame, let moved = latestFrame.onRecordingClock(clock, hostTime: CMClockGetTime(CMClockGetHostTimeClock())) else { return }
            write(moved)
        }
    }

    /// Returns recording-clock times of the first frame and of the moment capture stopped.
    func stop() async throws -> (start: Double, end: Double) {
        try await stream?.stopCapture()
        stream = nil
        let end = CMTime(seconds: clock.recordingTime(endingAt: HostClock.now()), preferredTimescale: 1_000_000_000)

        let (writer, input, first, last) = queue.sync { (self.writer, self.input, firstFrameTime, lastFrameTime) }
        guard let writer, let input, let first, let last else { throw RecorderError.noFrames }

        input.markAsFinished()
        writer.endSession(atSourceTime: CMTimeMaximum(end, last))
        await writer.finishWriting()
        if writer.status != .completed { throw RecorderError.writer(writer.error) }
        return (first.seconds, CMTimeMaximum(end, last).seconds)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard buffer.isValid else { return }
        switch type {
        case .screen:
            guard Self.isCompleteFrame(buffer) else { return }
            latestFrame = buffer
            if let moved = buffer.onRecordingClock(clock) { write(moved) }
        case .audio:
            if let moved = buffer.onRecordingClock(clock) { systemAudio?.append(moved) }
        default:
            break
        }
    }

    /// Runs on `queue`; `buffer` is already on the recording clock.
    private func write(_ buffer: CMSampleBuffer) {
        guard let writer, let input else { return }
        let time = buffer.presentationTimeStamp
        if firstFrameTime == nil {
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: time)
            firstFrameTime = time
        }
        if let lastFrameTime, time <= lastFrameTime { return }
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
