import CoreGraphics
import Foundation
import ZoomEngine

/// How the camera bubble looks in the video. Missing keys in a stored copy keep their defaults.
struct CameraLook: Equatable {
    enum Position: String, Codable, CaseIterable {
        case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight
    }

    enum Aspect: String, Codable, CaseIterable {
        case square, wide, classic, portrait, tall

        /// Width over height.
        var ratio: Double {
            switch self {
            case .square: 1
            case .wide: 16.0 / 9
            case .classic: 4.0 / 3
            case .portrait: 3.0 / 4
            case .tall: 9.0 / 16
            }
        }
    }

    /// The bubble's short side as a fraction of the canvas's short side.
    var size = 0.35
    /// Corner radius as a fraction of the bubble's short side; 0.5 on a square makes a circle.
    var roundness = 0.15
    var aspect = Aspect.square
    var position = Position.bottomRight
    var mirrored = false
    var shrinksOnZoom = true
}

extension CameraLook: Codable {
    private enum Key: String, CodingKey { case size, roundness, aspect, position, mirrored, shrinksOnZoom }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        func value<T: Decodable>(_ key: Key, _ fallback: T) -> T { ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback }
        let defaults = CameraLook()
        size = value(.size, defaults.size)
        roundness = value(.roundness, defaults.roundness)
        aspect = value(.aspect, defaults.aspect)
        position = value(.position, defaults.position)
        mirrored = value(.mirrored, defaults.mirrored)
        shrinksOnZoom = value(.shrinksOnZoom, defaults.shrinksOnZoom)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(size, forKey: .size)
        try c.encode(roundness, forKey: .roundness)
        try c.encode(aspect, forKey: .aspect)
        try c.encode(position, forKey: .position)
        try c.encode(mirrored, forKey: .mirrored)
        try c.encode(shrinksOnZoom, forKey: .shrinksOnZoom)
    }
}

/// A stretch where the camera leaves its usual bubble.
struct CameraSpan: TimeSpan, Codable {
    enum Layout: String, Codable, CaseIterable {
        case hidden
        /// Screen and camera share the canvas as two cards.
        case split
        /// The camera covers the whole canvas.
        case full
    }

    var start: Double
    var end: Double
    var layout: Layout
}

/// Where the camera sits on the canvas. Rects use a top-left origin.
enum CameraLayout {
    /// Seconds the camera and screen take to move into a layout and back out.
    static let transition = 0.35
    /// Seconds a hidden camera takes to fade.
    static let fade = 0.25

    /// The layout at `time` and how far into it things have moved, from 0 to 1.
    static func arrangement(at time: Double, spans: [CameraSpan]) -> (layout: CameraSpan.Layout, amount: Double)? {
        guard let span = spans.first(where: { $0.contains(time) }) else { return nil }
        let edge = min(time - span.start, span.end - time)
        if span.layout == .hidden { return (.hidden, min(max(edge / fade, 0), 1)) }
        let linear = min(max(edge / transition, 0), 1)
        return (span.layout, linear * linear * (3 - 2 * linear))
    }

    /// Two cards of the same height side by side, or of the same width stacked on a tall canvas.
    /// The screen keeps its shape and the camera fills what is left of its half.
    static func split(canvas: CGSize, source: CGSize) -> (screen: CGRect, camera: CGRect) {
        let gap = min(canvas.width, canvas.height) * 0.05
        let ratio = source.width / max(source.height, 1)
        if canvas.width >= canvas.height {
            let half = CGSize(width: (canvas.width - 3 * gap) / 2, height: canvas.height - 2 * gap)
            let width = min(half.width, half.height * ratio), height = width / ratio
            let left = (canvas.width - width - gap - half.width) / 2, top = (canvas.height - height) / 2
            return (CGRect(x: left, y: top, width: width, height: height),
                    CGRect(x: left + width + gap, y: top, width: half.width, height: height))
        }
        let half = CGSize(width: canvas.width - 2 * gap, height: (canvas.height - 3 * gap) / 2)
        let width = min(half.width, half.height * ratio), height = width / ratio
        let left = (canvas.width - width) / 2, top = (canvas.height - height - gap - half.height) / 2
        return (CGRect(x: left, y: top, width: width, height: height),
                CGRect(x: left, y: top + height + gap, width: width, height: half.height))
    }

    /// Gap between the bubble and the canvas edge.
    static func margin(_ canvas: CGSize) -> Double {
        min(canvas.width, canvas.height) * 0.04
    }

    /// `zoomProgress` runs from 0 at rest to 1 at full zoom; the bubble gives way to the screen
    /// by shrinking toward its corner.
    static func frame(canvas: CGSize, look: CameraLook, zoomProgress: Double) -> CGRect {
        let shrink = look.shrinksOnZoom ? 1 - 0.2 * min(max(zoomProgress, 0), 1) : 1
        let short = min(canvas.width, canvas.height) * look.size * shrink
        let ratio = look.aspect.ratio
        let size = ratio >= 1 ? CGSize(width: short * ratio, height: short) : CGSize(width: short, height: short / ratio)
        let margin = margin(canvas)
        let x: Double, y: Double
        switch look.position {
        case .topLeft, .left, .bottomLeft: x = margin
        case .top, .bottom: x = (canvas.width - size.width) / 2
        case .topRight, .right, .bottomRight: x = canvas.width - margin - size.width
        }
        switch look.position {
        case .topLeft, .top, .topRight: y = margin
        case .left, .right: y = (canvas.height - size.height) / 2
        case .bottomLeft, .bottom, .bottomRight: y = canvas.height - margin - size.height
        }
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    static func cornerRadius(_ frame: CGRect, look: CameraLook) -> Double {
        min(frame.width, frame.height) * look.roundness
    }
}
