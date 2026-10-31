import AppKit
import ImageIO
import UniformTypeIdentifiers
import ZoomEngine

/// Records cursor position, mouse buttons and cursor shape while the screen is captured.
/// Everything is polled, which needs no permission beyond screen recording.
final class InputRecorder {
    private let displayBounds: CGRect
    private let scale: Double
    private let window: WindowTracker?
    private let pixelSize: CGSize
    private let queue = DispatchQueue(label: "avora.input", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var shapeTimer: Timer?
    private let shapes = CursorShapeTracker()

    private var cursor: [CursorSample] = []
    private var clicks: [ClickEvent] = []
    private var lastTick: (time: Double, position: CGPoint, shape: Int?)?
    private var buttonsDown = false

    static let sampleRate = 120.0
    static let shapeRate = 20.0

    /// `displayBounds` is in global points with a top-left origin, as `CGDisplayBounds` returns.
    init(displayBounds: CGRect, scale: Double, window: WindowTracker? = nil, pixelSize: CGSize = .zero) {
        self.displayBounds = displayBounds
        self.scale = scale
        self.window = window
        self.pixelSize = pixelSize
    }

    func start() {
        shapes.sample()
        let shapeTimer = Timer(timeInterval: 1 / Self.shapeRate, repeats: true) { [shapes] _ in shapes.sample() }
        RunLoop.main.add(shapeTimer, forMode: .common)
        self.shapeTimer = shapeTimer

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1 / Self.sampleRate, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        shapeTimer?.invalidate()
        queue.sync { timer?.cancel() }
    }

    /// Drops input from paused stretches, shifts times so 0 is the first video frame and writes
    /// cursor images into `cursorFolder`. `videoStart` and `videoEnd` are on the recording clock.
    func makeLog(clock: RecordingClock, videoStart: Double, videoEnd: Double, sourceSize: CGSize, cursorFolder: URL) throws -> InputLog {
        let (cursor, clicks) = queue.sync { (self.cursor, self.clicks) }
        let duration = videoEnd - videoStart
        let time = { (host: Double) in clock.recordingTime(forHost: host).map { $0 - videoStart } }
        let keep = { (time: Double) in time >= -1 && time <= duration + 1 }
        // Clicks outside a recorded area or window must not pull the camera toward the edge.
        let inside = { (point: CGPoint) in CGRect(origin: .zero, size: sourceSize).contains(point) }
        return InputLog(
            sourceSize: sourceSize,
            pointPixelScale: scale,
            duration: duration,
            cursor: cursor.compactMap { sample in
                time(sample.time).map { CursorSample(time: $0, position: sample.position, shape: sample.shape) }
            }.filter { keep($0.time) },
            clicks: clicks.compactMap { click in
                time(click.time).map { ClickEvent(time: $0, position: click.position, isDown: click.isDown) }
            }.filter { keep($0.time) && inside($0.position) },
            shapes: try shapes.save(to: cursorFolder)
        )
    }

    private func tick() {
        let now = HostClock.now()
        guard let location = CGEvent(source: nil)?.location else { return }
        let position = window.map { CaptureGeometry.pixel(for: location, in: $0.frame, pixelSize: pixelSize) } ?? CGPoint(
            x: (location.x - displayBounds.minX) * scale,
            y: (location.y - displayBounds.minY) * scale
        )
        let shape = shapes.current

        if let last = lastTick, last.position != position || last.shape != shape {
            // Re-emit the resting position so interpolation does not drift across a pause.
            if let recorded = cursor.last, recorded.time < last.time {
                cursor.append(CursorSample(time: last.time, position: last.position, shape: last.shape))
            }
            cursor.append(CursorSample(time: now, position: position, shape: shape))
        } else if lastTick == nil {
            cursor.append(CursorSample(time: now, position: position, shape: shape))
        }
        lastTick = (now, position, shape)

        let down = [CGMouseButton.left, .right, .center].contains {
            CGEventSource.buttonState(.combinedSessionState, button: $0)
        }
        if down != buttonsDown {
            clicks.append(ClickEvent(time: now, position: position, isDown: down))
            buttonsDown = down
        }
    }
}

/// Watches the system cursor image and keeps one copy of every distinct shape.
final class CursorShapeTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var currentID: Int?
    private var idsByHash: [Int: Int] = [:]
    private var captured: [(cursor: NSCursor, id: Int)] = []

    var current: Int? {
        lock.withLock { currentID }
    }

    /// Must run on the main thread because it touches AppKit.
    func sample() {
        guard let cursor = NSCursor.currentSystem, let data = cursor.image.tiffRepresentation else { return }
        let hash = data.hashValue
        lock.withLock {
            if let id = idsByHash[hash] {
                currentID = id
                return
            }
            let id = captured.count
            idsByHash[hash] = id
            captured.append((cursor, id))
            currentID = id
        }
    }

    func save(to folder: URL) throws -> [CursorShape] {
        let captured = lock.withLock { self.captured }
        return try captured.compactMap { cursor, id in
            guard let image = Self.largestImage(of: cursor.image) else { return nil }
            let file = "cursor-\(id).png"
            try Self.writePNG(image, to: folder.appending(path: file))
            return CursorShape(id: id, file: file, hotspot: cursor.hotSpot, size: cursor.image.size)
        }
    }

    private static func largestImage(of image: NSImage) -> CGImage? {
        let best = image.representations.max { $0.pixelsWide < $1.pixelsWide }
        var rect = CGRect(x: 0, y: 0, width: best?.pixelsWide ?? 0, height: best?.pixelsHigh ?? 0)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
