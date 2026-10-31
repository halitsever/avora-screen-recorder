import AVFoundation

extension CMSampleBuffer {
    /// The same samples moved onto the recording clock. nil when they fall inside a pause.
    func onRecordingClock(_ clock: RecordingClock, hostTime: CMTime? = nil) -> CMSampleBuffer? {
        let host = hostTime ?? presentationTimeStamp
        guard let recording = clock.recordingTime(forHost: host.seconds) else { return nil }
        let offset = CMTimeSubtract(CMTime(seconds: recording, preferredTimescale: host.timescale), presentationTimeStamp)
        return retimed { CMTimeAdd($0, offset) }
    }

    private func retimed(_ move: (CMTime) -> CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        var timing = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(self, entryCount: count, arrayToFill: &timing, entriesNeededOut: nil)
        for index in timing.indices {
            timing[index].presentationTimeStamp = move(timing[index].presentationTimeStamp)
            if timing[index].decodeTimeStamp.isValid { timing[index].decodeTimeStamp = move(timing[index].decodeTimeStamp) }
        }
        var copy: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: self, sampleTimingEntryCount: count,
                                              sampleTimingArray: &timing, sampleBufferOut: &copy)
        return copy
    }
}

/// Writes one audio source to its own file while recording. The file starts at its first sample,
/// and `start` says where that is on the recording clock.
final class AudioTrackWriter: @unchecked Sendable {
    let url: URL
    private let lock = NSLock()
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var start: CMTime?

    init(url: URL) {
        self.url = url
    }

    /// `buffer` must already be on the recording clock.
    func append(_ buffer: CMSampleBuffer) {
        lock.withLock {
            if writer == nil, !open(for: buffer) { return }
            guard let input, writer?.status == .writing, input.isReadyForMoreMediaData else { return }
            input.append(buffer)
        }
    }

    /// Recording-clock time of the first sample, or nil when nothing was written.
    func finish() async -> Double? {
        let (writer, input, start) = lock.withLock { (self.writer, self.input, self.start) }
        guard let writer, let input, let start else { return nil }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed ? start.seconds : nil
    }

    private func open(for buffer: CMSampleBuffer) -> Bool {
        guard let format = buffer.formatDescription?.audioStreamBasicDescription,
              let writer = try? AVAssetWriter(outputURL: url, fileType: .m4a)
        else { return false }
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.mSampleRate,
            AVNumberOfChannelsKey: min(Int(format.mChannelsPerFrame), 2),
            AVEncoderBitRateKey: 192_000,
        ])
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { return false }
        writer.add(input)
        guard writer.startWriting() else { return false }
        writer.startSession(atSourceTime: buffer.presentationTimeStamp)
        (self.writer, self.input, start) = (writer, input, buffer.presentationTimeStamp)
        return true
    }
}

enum MicrophoneError: LocalizedError {
    case denied
    case unavailable

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!

    var errorDescription: String? {
        switch self {
        case .denied: "Avora needs Microphone permission to record your voice. Enable it in System Settings > Privacy & Security > Microphone, or turn the microphone off in Avora's settings."
        case .unavailable: "The microphone picked in Avora's settings is not connected. Pick another one or turn the microphone off."
        }
    }
}

/// Records one microphone through AVCaptureSession, moved onto the recording clock.
final class MicrophoneRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "avora.microphone", qos: .userInteractive)
    private let clock: RecordingClock
    private let writer: AudioTrackWriter

    static var devices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified).devices
    }

    init(deviceID: String, clock: RecordingClock, writer: AudioTrackWriter) async throws {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { throw MicrophoneError.denied }
        guard let device = AVCaptureDevice(uniqueID: deviceID) else { throw MicrophoneError.unavailable }
        self.clock = clock
        self.writer = writer
        super.init()

        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        session.beginConfiguration()
        guard session.canAddInput(input), session.canAddOutput(output) else { throw MicrophoneError.unavailable }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
    }

    func start() {
        session.startRunning()
    }

    func stop() {
        session.stopRunning()
        queue.sync {}
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Capture sessions run on their own clock; screen frames use host time.
        let host = session.synchronizationClock.map {
            CMSyncConvertTime(buffer.presentationTimeStamp, from: $0, to: CMClockGetHostTimeClock())
        } ?? buffer.presentationTimeStamp
        if let moved = buffer.onRecordingClock(clock, hostTime: host) { writer.append(moved) }
    }
}
