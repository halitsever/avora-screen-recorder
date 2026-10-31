import CoreGraphics

/// Everything the recorder captured besides the video. Positions are in source video pixels,
/// origin at the top-left; times are seconds from the first video frame.
public struct InputLog: Codable, Sendable, Equatable {
    public var version = 1
    public var sourceSize: CGSize
    public var pointPixelScale: Double
    public var duration: Double
    public var cursor: [CursorSample]
    public var clicks: [ClickEvent]
    public var shapes: [CursorShape]

    public init(
        sourceSize: CGSize,
        pointPixelScale: Double,
        duration: Double,
        cursor: [CursorSample] = [],
        clicks: [ClickEvent] = [],
        shapes: [CursorShape] = []
    ) {
        self.sourceSize = sourceSize
        self.pointPixelScale = pointPixelScale
        self.duration = duration
        self.cursor = cursor
        self.clicks = clicks
        self.shapes = shapes
    }
}

public struct CursorSample: Codable, Sendable, Equatable {
    public var time: Double
    public var position: CGPoint
    public var shape: Int?

    public init(time: Double, position: CGPoint, shape: Int? = nil) {
        self.time = time
        self.position = position
        self.shape = shape
    }
}

public struct ClickEvent: Codable, Sendable, Equatable {
    public var time: Double
    public var position: CGPoint
    public var isDown: Bool

    public init(time: Double, position: CGPoint, isDown: Bool) {
        self.time = time
        self.position = position
        self.isDown = isDown
    }
}

/// A cursor image saved next to the log. `hotspot` and `size` are in points.
public struct CursorShape: Codable, Sendable, Equatable {
    public var id: Int
    public var file: String
    public var hotspot: CGPoint
    public var size: CGSize

    public init(id: Int, file: String, hotspot: CGPoint, size: CGSize) {
        self.id = id
        self.file = file
        self.hotspot = hotspot
        self.size = size
    }
}
