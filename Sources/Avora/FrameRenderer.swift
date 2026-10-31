import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ZoomEngine

/// Look of the exported video. Ratios are relative to the canvas or screen size so output
/// looks the same at any resolution.
struct OutputStyle {
    var fps = 60.0
    var maxWidth = 3840.0
    var padding = 0.06
    var cornerRadius = 0.012
    var shadowBlur = 0.02
    var shadowOpacity = 0.45
    var cursorScale = 1.5
    var backgroundParallax = 0.125
    var background = BackgroundPreset.named(nil)

    func canvasSize(for source: CGSize) -> CGSize {
        let ratio = min(1, maxWidth / source.width)
        return CGSize(width: even(source.width * ratio), height: even(source.height * ratio))
    }

    func baseRect(in canvas: CGSize) -> CGRect {
        CGRect(origin: .zero, size: canvas).insetBy(dx: canvas.width * padding, dy: canvas.height * padding)
    }

    private func even(_ value: Double) -> Double { (value / 2).rounded() * 2 }
}

private struct CursorImage {
    let image: CIImage
    /// Hotspot and size in points.
    let hotspot: CGPoint
    let size: CGSize
}

/// Composes one output frame: backdrop, shadow, zoomed screen and cursor.
final class FrameRenderer: @unchecked Sendable {
    let canvas: CGSize
    private let style: OutputStyle
    private let base: CGRect
    private let log: InputLog
    private let frames: [FrameState]
    private let cursors: [Int: CursorImage]
    private let fallbackCursor: CursorImage?
    private let background: CIImage

    init(log: InputLog, cursorFolder: URL, style: OutputStyle) {
        self.style = style
        self.log = log
        canvas = style.canvasSize(for: log.sourceSize)
        base = style.baseRect(in: canvas)
        frames = Director(log: log, base: base).frames(fps: style.fps)

        var cursors: [Int: CursorImage] = [:]
        for shape in log.shapes {
            if let image = CIImage(contentsOf: cursorFolder.appending(path: shape.file)) {
                cursors[shape.id] = CursorImage(image: image, hotspot: shape.hotspot, size: shape.size)
            }
        }
        self.cursors = cursors
        fallbackCursor = Self.arrowCursor()
        // Clamped so resampling during the parallax zoom never blends transparent pixels into the edges.
        background = style.background.image(size: canvas).clampedToExtent()
    }

    func render(source: CIImage, at time: Double) -> CIImage {
        guard !frames.isEmpty else { return source }
        let index = min(max(Int((time * style.fps).rounded()), 0), frames.count - 1)
        let state = frames[index]
        let screen = state.screenRect
        let bounds = CGRect(origin: .zero, size: canvas)
        let zoom = screen.width / base.width

        var output = background
            .transformed(by: scaling(1 + max(zoom - 1, 0) * style.backgroundParallax, around: parallaxAnchor(screen)))
            .cropped(to: bounds)

        let radius = style.cornerRadius * screen.width
        let shadowBlur = style.shadowBlur * screen.width
        let shadow = roundedRect(flipped(screen).offsetBy(dx: 0, dy: -shadowBlur / 3), radius: radius,
                                 color: CIColor(red: 0, green: 0, blue: 0, alpha: style.shadowOpacity))
            .applyingGaussianBlur(sigma: shadowBlur)
        output = shadow.composited(over: output)

        let placed = source.clampedToExtent().transformed(by: placement(of: log.sourceSize, in: flipped(screen)))
        let mask = roundedRect(flipped(screen), radius: radius, color: .white)
        output = placed.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: mask])
            .composited(over: output)

        if let cursor = cursorLayer(for: state, screen: screen) {
            output = cursor.composited(over: output)
        }
        return output.cropped(to: bounds)
    }

    private func cursorLayer(for state: FrameState, screen: CGRect) -> CIImage? {
        guard let point = state.cursor,
              let cursor = state.cursorShape.flatMap({ cursors[$0] }) ?? fallbackCursor
        else { return nil }

        let canvasPerSourcePixel = screen.width / log.sourceSize.width
        let canvasPerPoint = canvasPerSourcePixel * log.pointPixelScale * style.cursorScale
        let size = CGSize(width: cursor.size.width * canvasPerPoint, height: cursor.size.height * canvasPerPoint)
        let tip = CGPoint(x: screen.minX + point.x * canvasPerSourcePixel, y: screen.minY + point.y * canvasPerSourcePixel)
        let topLeft = CGPoint(x: tip.x - cursor.hotspot.x * canvasPerPoint, y: tip.y - cursor.hotspot.y * canvasPerPoint)
        let frame = flipped(CGRect(origin: topLeft, size: size))
        return cursor.image.transformed(by: placement(of: cursor.image.extent.size, in: frame))
    }

    /// The part of the screen under the base center, so the backdrop drifts along with the zoom.
    private func parallaxAnchor(_ screen: CGRect) -> CGPoint {
        let x = min(max((base.midX - screen.minX) / screen.width, 0), 1)
        let y = min(max((base.midY - screen.minY) / screen.height, 0), 1)
        return CGPoint(x: x * canvas.width, y: canvas.height - y * canvas.height)
    }

    /// Converts a top-left origin rect to Core Image's bottom-left space.
    private func flipped(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: canvas.height - rect.maxY, width: rect.width, height: rect.height)
    }

    private func placement(of size: CGSize, in frame: CGRect) -> CGAffineTransform {
        CGAffineTransform(scaleX: frame.width / size.width, y: frame.height / size.height)
            .concatenating(CGAffineTransform(translationX: frame.minX, y: frame.minY))
    }

    private func scaling(_ factor: Double, around point: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -point.x, y: -point.y)
            .concatenating(CGAffineTransform(scaleX: factor, y: factor))
            .concatenating(CGAffineTransform(translationX: point.x, y: point.y))
    }

    private func roundedRect(_ rect: CGRect, radius: Double, color: CIColor) -> CIImage {
        let filter = CIFilter.roundedRectangleGenerator()
        filter.extent = rect
        filter.radius = Float(radius)
        filter.color = color
        return filter.outputImage ?? CIImage.empty()
    }

    /// A drawn pointer for recordings that carry no cursor images.
    private static func arrowCursor() -> CursorImage? {
        let size = CGSize(width: 18, height: 24)
        let margin = 3.0
        let pixelsPerPoint = 10.0
        guard let context = CGContext(
            data: nil, width: Int(size.width * pixelsPerPoint), height: Int(size.height * pixelsPerPoint),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.scaleBy(x: pixelsPerPoint, y: -pixelsPerPoint)
        context.translateBy(x: margin, y: -size.height + margin)
        let outline: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 16), CGPoint(x: 4, y: 12.4), CGPoint(x: 6.6, y: 18.2),
            CGPoint(x: 9.2, y: 17.1), CGPoint(x: 6.7, y: 11.5), CGPoint(x: 11.6, y: 11.5),
        ]
        let path = CGMutablePath()
        path.addLines(between: outline)
        path.closeSubpath()

        context.setShadow(offset: CGSize(width: 0, height: -0.6), blur: 1.6, color: CGColor(gray: 0, alpha: 0.35))
        context.setLineJoin(.round)
        context.setLineWidth(2.2)
        context.setStrokeColor(.white)
        context.addPath(path)
        context.strokePath()
        context.setShadow(offset: .zero, blur: 0)
        context.setFillColor(.black)
        context.addPath(path)
        context.fillPath()

        guard let image = context.makeImage() else { return nil }
        return CursorImage(image: CIImage(cgImage: image), hotspot: CGPoint(x: margin, y: margin), size: size)
    }
}
