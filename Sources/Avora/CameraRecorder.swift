import AVFoundation
import AppKit

enum CameraError: LocalizedError {
    case denied
    case unavailable

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!

    var errorDescription: String? {
        switch self {
        case .denied: "Avora needs Camera permission to record you. Enable it in System Settings > Privacy & Security > Camera, or turn the camera off in Avora's settings."
        case .unavailable: "The camera picked in Avora's settings is not connected. Pick another one or turn the camera off."
        }
    }
}

/// Where the camera file starts, in seconds after the first screen frame.
struct CameraManifest: Codable {
    var file: String
    var offset: Double
    /// Seconds the picture runs behind the voice, measured from the lips; nil when it couldn't be told.
    var sync: Double?

    /// Where the camera belongs once its picture is lined up with the voice.
    var syncedOffset: Double { offset - (sync ?? 0) }
}

/// Records one camera through AVCaptureSession, moved onto the recording clock. The same
/// session feeds the preview bubble.
final class CameraRecorder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "avora.camera", qos: .userInteractive)
    private let clock: RecordingClock
    private let writer: CameraTrackWriter

    static var devices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                         mediaType: .video, position: .unspecified).devices
    }

    init(deviceID: String, clock: RecordingClock, writer: CameraTrackWriter, maxHeight: Int32 = 1080) async throws {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { throw CameraError.denied }
        guard let device = AVCaptureDevice(uniqueID: deviceID) else { throw CameraError.unavailable }
        self.clock = clock
        self.writer = writer
        super.init()

        // The widest format that stays within the height limit; frame rate stays the camera's own.
        let fitting = device.formats
            .filter { CMVideoFormatDescriptionGetDimensions($0.formatDescription).height <= maxHeight }
            .max { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width }
        if let fitting, (try? device.lockForConfiguration()) != nil {
            device.activeFormat = fitting
            device.unlockForConfiguration()
        }

        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        session.beginConfiguration()
        guard session.canAddInput(input), session.canAddOutput(output) else { throw CameraError.unavailable }
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
        let host = session.synchronizationClock.map {
            CMSyncConvertTime(buffer.presentationTimeStamp, from: $0, to: CMClockGetHostTimeClock())
        } ?? buffer.presentationTimeStamp
        if let moved = buffer.onRecordingClock(clock, hostTime: host) { writer.append(moved) }
    }
}

/// A small floating window showing the camera while recording. Avora's own windows are left out
/// of the capture, so it never shows up in the video.
@MainActor
final class CameraPreviewPanel {
    private let panel: NSPanel

    init(session: AVCaptureSession) {
        let size: CGFloat = 200
        let visible = NSScreen.main?.visibleFrame ?? .zero
        panel = NSPanel(contentRect: CGRect(x: visible.maxX - size - 40, y: visible.minY + 40, width: size, height: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameAutosaveName("AvoraCameraPreview")

        let view = NSView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.wantsLayer = true
        view.layer?.cornerRadius = size * 0.15
        view.layer?.masksToBounds = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        // Seeing yourself mirrored feels natural; the recording keeps the camera's own view.
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        view.layer?.addSublayer(preview)
        panel.contentView = view
    }

    func show() { panel.orderFrontRegardless() }
    func close() { panel.orderOut(nil) }
}
