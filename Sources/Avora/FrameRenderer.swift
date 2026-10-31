import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ZoomEngine

/// Look of the exported video. Ratios are relative to the canvas or screen size so output
/// looks the same at any resolution.
struct OutputStyle {
    var fps = 60.0
    var resolution = RenderSettings.Resolution.source
    var aspect = RenderSettings.Aspect.auto
    var backgroundBlur = 0.0
    var maxWidth = 3840.0
    var padding = 0.06
    var cornerRadius = 0.012
    var shadowBlur = 0.02
    var shadowOpacity = 0.45
    var cursorScale = 1.5
    var backgroundParallax = 0.125
    /// 0 turns motion blur off; 1 exposes each frame for 1/60 s.
    var motionBlur = 1.0
    var zoomScale = 2.0
    var cursorSpring: SpringConfig? = .cursor
    var background = BackgroundPreset.named(nil)
    var format = RenderSettings.Format.h264
    var quality = RenderSettings.Quality.social
    var showsCursor = true
    var clickEffect = RenderSettings.ClickEffect.none
    /// Seconds of rest before the cursor fades out; nil keeps it on screen.
    var idleDelay: Double?
    var cursorFreeze = 0.0
    var camera = CameraLook()
    var showsShortcuts = false
    var voice = VoicePreset.standard
    var burnsCaptions = false
    var savesSubtitles = false
    var captionLocale = Locale.current

    init(background: BackgroundPreset = .named(nil)) {
        self.background = background
    }

    init(settings: RenderSettings, background: BackgroundPreset) {
        self.background = background
        format = settings.format
        quality = settings.quality
        let gif = settings.format == .gif
        fps = gif ? RenderSettings.gifFPS : Double(settings.fps)
        resolution = settings.resolution
        aspect = settings.aspect
        backgroundBlur = settings.backgroundBlur
        maxWidth = gif ? RenderSettings.gifMaxWidth : 3840
        padding = settings.padding
        cornerRadius = settings.cornerRadius
        shadowOpacity = settings.shadow
        cursorScale = settings.cursorScale
        motionBlur = settings.motionBlur
        zoomScale = settings.zoom
        cursorSpring = settings.smoothing.spring
        showsCursor = settings.showsCursor
        clickEffect = settings.clickEffect
        idleDelay = settings.hidesIdleCursor ? 2 : nil
        cursorFreeze = settings.cursorFreeze
        camera = settings.camera
        showsShortcuts = settings.showsShortcuts
        voice = settings.voice
        burnsCaptions = settings.burnsCaptions
        savesSubtitles = settings.savesSubtitles
        captionLocale = settings.captionLocale
    }

    /// The resolution sets the short side of a fixed ratio, so vertical 1080p is 1080×1920.
    func canvasSize(for source: CGSize) -> CGSize {
        var size = resolution.canvasSize(for: source)
        if let ratio = aspect.ratio {
            let short = min(size.height, size.width)
            size = ratio >= 1 ? CGSize(width: short * ratio, height: short) : CGSize(width: short, height: short / ratio)
            let fit = min(1, 3840 / max(size.width, size.height))
            size = CGSize(width: size.width * fit, height: size.height * fit)
        }
        let ratio = min(1, maxWidth / size.width)
        return CGSize(width: even(size.width * ratio), height: even(size.height * ratio))
    }

    /// Where the screen rests: inside the padding, keeping the recording's shape, centered.
    /// The canvas inside the padding.
    func stageRect(in canvas: CGSize) -> CGRect {
        CGRect(origin: .zero, size: canvas).insetBy(dx: canvas.width * padding, dy: canvas.height * padding)
    }

    func baseRect(in canvas: CGSize, source: CGSize) -> CGRect {
        let available = stageRect(in: canvas)
        let scale = min(available.width / source.width, available.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(x: available.midX - size.width / 2, y: available.midY - size.height / 2, width: size.width, height: size.height)
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
    private let visibility: CursorVisibility
    private let presses: [ClickEvent]
    private let effect: CIImage?
    /// The kept part of the source in Core Image space (bottom-left origin); nil keeps all of it.
    private let crop: CGRect?
    private let cameraSpans: [CameraSpan]
    private let masks: [Mask]
    private let keys: [KeyPress]
    private let captions: [Caption]
    private let badges = NSCache<NSString, CIImage>()

    init(log recorded: InputLog, cursorFolder: URL, style: OutputStyle, edits: RecordingEdits? = nil, keys: [KeyPress] = []) {
        self.style = style
        self.keys = style.showsShortcuts ? keys : []
        var log = recorded.freezingCursor(last: style.cursorFreeze)
        var zooms = edits?.zooms
        if let fraction = edits?.crop {
            let pixels = RecordingEdits.cropPixels(fraction, source: log.sourceSize)
            crop = CGRect(x: pixels.minX, y: log.sourceSize.height - pixels.maxY, width: pixels.width, height: pixels.height)
            // Manual focus points were picked on the whole frame.
            zooms = zooms?.map { zoom in
                var zoom = zoom
                zoom.focus = zoom.focus.map {
                    CGPoint(x: ($0.x * log.sourceSize.width - pixels.minX) / pixels.width,
                            y: ($0.y * log.sourceSize.height - pixels.minY) / pixels.height)
                }
                return zoom
            }
            log = log.cropped(to: pixels)
        } else {
            crop = nil
        }
        self.log = log
        cameraSpans = edits?.camera ?? []
        masks = edits?.masks ?? []
        captions = style.burnsCaptions ? edits?.captions ?? [] : []
        canvas = style.canvasSize(for: log.sourceSize)
        base = style.baseRect(in: canvas, source: log.sourceSize)
        // In another shape than the recording's, a zoom fills the padded canvas instead of leaving bands of backdrop.
        let stage = style.aspect == .auto ? nil : style.stageRect(in: canvas)
        frames = Director(log: log, base: base, stage: stage, zoom: ZoomConfig(scale: style.zoomScale), segments: zooms, cursorSpring: style.cursorSpring)
            .frames(fps: style.fps)
        visibility = CursorVisibility(log: log, idleDelay: style.idleDelay, hidden: edits?.cursorHidden ?? [])
        presses = log.clicks
        effect = Self.effectImage(style.clickEffect)

        var cursors: [Int: CursorImage] = [:]
        for shape in log.shapes {
            if let image = CIImage(contentsOf: cursorFolder.appending(path: shape.file)) {
                cursors[shape.id] = CursorImage(image: image, hotspot: shape.hotspot, size: shape.size)
            }
        }
        self.cursors = cursors
        fallbackCursor = Self.arrowCursor()
        var backdrop = style.background.image(size: canvas)
        if style.backgroundBlur > 0 {
            let bounds = CGRect(origin: .zero, size: canvas)
            backdrop = backdrop.clampedToExtent()
                .applyingGaussianBlur(sigma: style.backgroundBlur * 0.03 * max(canvas.width, canvas.height))
                .cropped(to: bounds)
        }
        // Clamped so resampling during the parallax zoom never blends transparent pixels into the edges.
        background = backdrop.clampedToExtent()
    }

    func render(source: CIImage, camera: CIImage? = nil, at time: Double) -> CIImage {
        guard !frames.isEmpty else { return source }
        let index = min(max(Int((time * style.fps).rounded()), 0), frames.count - 1)
        let state = frames[index]
        let previous = frames[max(index - 1, 0)]
        let screen = state.screenRect
        let bounds = CGRect(origin: .zero, size: canvas)
        let zoom = screen.width / base.width

        var output = background
            .transformed(by: scaling(1 + max(zoom - 1, 0) * style.backgroundParallax, around: parallaxAnchor(screen)))
            .cropped(to: bounds)

        // Masks are placed on the whole recorded frame, so they go on before the crop.
        let source = Masking.apply(masks, to: source, at: time)
        let kept = crop.map { source.cropped(to: $0).transformed(by: CGAffineTransform(translationX: -$0.minX, y: -$0.minY)) } ?? source
        let placed = kept.clampedToExtent()
        let trail = MotionTrail.rects(from: previous.screenRect, to: screen, amount: style.motionBlur, fps: style.fps)
        var content = Self.average(trail.map { screenLayer(placed, at: $0) })

        let opacity = style.showsCursor ? visibility.opacity(at: time) : 0
        if opacity > 0, let effects = clickEffects(at: time, screen: screen) {
            content = effects.composited(over: content)
        }
        if opacity > 0, let tip = cursorTip(state), let cursor = state.cursorShape.flatMap({ cursors[$0] }) ?? fallbackCursor {
            let tips = cursorTip(previous).map {
                MotionTrail.points(from: $0, to: tip, amount: style.motionBlur, fps: style.fps)
            } ?? [tip]
            // A pressed button shrinks the cursor a little, the way a real click feels.
            let pressed = presses.last { $0.time <= time }?.isDown == true
            let layer = Self.average(tips.map { cursorLayer(cursor, tip: $0, screen: screen, scale: pressed ? 0.9 : 1) })
            content = Self.fade(layer, to: opacity).composited(over: content)
        }

        // Side by side, the whole screen moves into its card and zooms stay inside it.
        let arrangement = camera == nil ? nil : CameraLayout.arrangement(at: time, spans: cameraSpans)
        var shadowRect = screen
        if let arrangement, arrangement.layout == .split, arrangement.amount > 0 {
            let amount = arrangement.amount
            let card = CameraLayout.split(canvas: canvas, source: log.sourceSize).screen
            let scale = 1 + (card.width / base.width - 1) * amount
            let shift = CGPoint(x: (card.minX - card.width / base.width * base.minX) * amount,
                                y: (card.minY - card.width / base.width * base.minY) * amount)
            let clip = Self.mix(bounds, card, amount)
            content = content
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale)
                    .concatenating(CGAffineTransform(translationX: shift.x, y: canvas.height * (1 - scale) - shift.y)))
                .applyingFilter("CISourceInCompositing", parameters: [
                    kCIInputBackgroundImageKey: roundedRect(flipped(clip), radius: style.cornerRadius * card.width * amount, color: .white),
                ])
            let moved = CGRect(x: screen.minX * scale + shift.x, y: screen.minY * scale + shift.y,
                               width: screen.width * scale, height: screen.height * scale)
            shadowRect = moved.intersection(clip)
        }

        // One soft shadow at the current position; smearing it as well costs a blur per sample.
        let shadowBlur = style.shadowBlur * shadowRect.width
        let shadow = roundedRect(flipped(shadowRect).offsetBy(dx: 0, dy: -shadowBlur / 3), radius: style.cornerRadius * shadowRect.width,
                                 color: CIColor(red: 0, green: 0, blue: 0, alpha: style.shadowOpacity))
            .applyingGaussianBlur(sigma: shadowBlur)
        output = content.composited(over: shadow.composited(over: output))

        if let camera, let layer = cameraLayer(camera, zoom: zoom, arrangement: arrangement) {
            output = layer.composited(over: output)
        }
        if let shortcut = KeystrokeOverlay.visible(at: time, in: keys) {
            output = shortcutBadge(shortcut.label, opacity: shortcut.opacity).composited(over: output)
        }
        if let caption = captions.first(where: { $0.contains(time) }) {
            output = captionBadge(caption.text).composited(over: output)
        }
        return output.cropped(to: bounds)
    }

    /// Captions sit above where the shortcut badge goes, so both can show at once.
    private func captionBadge(_ text: String) -> CIImage {
        let key = "caption:" + text as NSString
        let badge = badges.object(forKey: key) ?? {
            let made = CaptionOverlay.badge(text, canvas: canvas)
            badges.setObject(made, forKey: key)
            return made
        }()
        return badge.transformed(by: CGAffineTransform(translationX: (canvas.width - badge.extent.width) / 2, y: canvas.height * 0.14))
    }

    /// The last shortcut, centered near the bottom of the canvas.
    private func shortcutBadge(_ label: String, opacity: Double) -> CIImage {
        let badge = badges.object(forKey: label as NSString) ?? {
            let made = KeystrokeOverlay.badge(label, canvas: canvas)
            badges.setObject(made, forKey: label as NSString)
            return made
        }()
        let placed = badge.transformed(by: CGAffineTransform(translationX: (canvas.width - badge.extent.width) / 2, y: canvas.height * 0.06))
        return Self.fade(placed, to: opacity)
    }

    /// The camera on top of everything, filled edge to edge. As a bubble it shrinks during zooms;
    /// in a layout it grows from the bubble into its card or the whole canvas.
    private func cameraLayer(_ camera: CIImage, zoom: Double, arrangement: (layout: CameraSpan.Layout, amount: Double)?) -> CIImage? {
        let opacity = arrangement?.layout == .hidden ? 1 - arrangement!.amount : 1
        guard opacity > 0, camera.extent.width > 0, camera.extent.height > 0 else { return nil }
        let progress = min(max((zoom - 1) / max(style.zoomScale - 1, 0.01), 0), 1)
        let bubble = CameraLayout.frame(canvas: canvas, look: style.camera, zoomProgress: progress)
        var rect = flipped(bubble)
        var radius = CameraLayout.cornerRadius(bubble, look: style.camera)
        if let arrangement, arrangement.layout != .hidden {
            let target: (rect: CGRect, radius: Double)
            if arrangement.layout == .split {
                let cards = CameraLayout.split(canvas: canvas, source: log.sourceSize)
                target = (cards.camera, style.cornerRadius * cards.screen.width)
            } else {
                target = (CGRect(origin: .zero, size: canvas), 0)
            }
            rect = flipped(Self.mix(bubble, target.rect, arrangement.amount))
            radius += (target.radius - radius) * arrangement.amount
        }

        var picture = camera.transformed(by: CGAffineTransform(translationX: -camera.extent.minX, y: -camera.extent.minY))
        if style.camera.mirrored {
            picture = picture.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -picture.extent.width, y: 0))
        }
        let scale = max(rect.width / picture.extent.width, rect.height / picture.extent.height)
        let scaled = picture.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let placed = scaled.transformed(by: CGAffineTransform(translationX: rect.midX - scaled.extent.width / 2,
                                                              y: rect.midY - scaled.extent.height / 2))
        let clipped = placed.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: roundedRect(rect, radius: radius, color: .white)])
        let blur = style.shadowBlur * rect.width
        let shadow = roundedRect(rect.offsetBy(dx: 0, dy: -blur / 3), radius: radius,
                                 color: CIColor(red: 0, green: 0, blue: 0, alpha: style.shadowOpacity))
            .applyingGaussianBlur(sigma: blur)
        return Self.fade(clipped.composited(over: shadow), to: opacity)
    }

    /// Hidden spans fade the camera out over their first quarter second and back in over their last.
    static func cameraOpacity(at time: Double, spans: [CameraSpan]) -> Double {
        guard let arrangement = CameraLayout.arrangement(at: time, spans: spans), arrangement.layout == .hidden else { return 1 }
        return 1 - arrangement.amount
    }

    static func mix(_ from: CGRect, _ to: CGRect, _ amount: Double) -> CGRect {
        CGRect(x: from.minX + (to.minX - from.minX) * amount, y: from.minY + (to.minY - from.minY) * amount,
               width: from.width + (to.width - from.width) * amount, height: from.height + (to.height - from.height) * amount)
    }

    /// Up to three recent clicks, each a disc or ring that grows and fades where it happened.
    private func clickEffects(at time: Double, screen: CGRect) -> CIImage? {
        guard let effect, style.clickEffect != .none else { return nil }
        let duration = style.clickEffect.duration
        let recent = presses.filter { $0.isDown && time >= $0.time && time - $0.time <= duration }.suffix(3)
        guard !recent.isEmpty else { return nil }
        let canvasPerSourcePixel = screen.width / log.sourceSize.width
        let canvasPerPoint = canvasPerSourcePixel * log.pointPixelScale * style.cursorScale
        return recent.reduce(CIImage.empty()) { layers, click in
            let progress = (time - click.time) / duration
            let grow = 1 - pow(1 - progress, 3)
            let radius = (style.clickEffect == .circle ? 14 + 10 * grow : 8 + 38 * grow) * canvasPerPoint
            let center = CGPoint(x: screen.minX + click.position.x * canvasPerSourcePixel,
                                 y: screen.minY + click.position.y * canvasPerSourcePixel)
            let frame = flipped(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            let strength = (style.clickEffect == .circle ? 0.38 : 0.75) * (1 - progress)
            return Self.fade(effect.transformed(by: placement(of: effect.extent.size, in: frame)), to: strength).composited(over: layers)
        }
    }

    private static func fade(_ image: CIImage, to opacity: Double) -> CIImage {
        guard opacity < 1 else { return image }
        return image.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)])
    }

    /// A soft white disc for the circle effect, a ring for the ripple.
    private static func effectImage(_ kind: RenderSettings.ClickEffect) -> CIImage? {
        guard kind != .none else { return nil }
        let size = 256
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        context.setShadow(offset: .zero, blur: 10, color: CGColor(gray: 0, alpha: 0.35))
        if kind == .circle {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fillEllipse(in: bounds.insetBy(dx: 12, dy: 12))
        } else {
            context.setStrokeColor(CGColor(gray: 1, alpha: 1))
            context.setLineWidth(12)
            context.strokeEllipse(in: bounds.insetBy(dx: 18, dy: 18))
        }
        return context.makeImage().map { CIImage(cgImage: $0) }
    }

    private func screenLayer(_ source: CIImage, at screen: CGRect) -> CIImage {
        let placed = source.transformed(by: placement(of: log.sourceSize, in: flipped(screen)))
        let mask = roundedRect(flipped(screen), radius: style.cornerRadius * screen.width, color: .white)
        return placed.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: mask])
    }

    /// The pointer tip in canvas coordinates (top-left origin); nil while it is outside the recorded area.
    private func cursorTip(_ state: FrameState) -> CGPoint? {
        guard let point = state.cursor, CGRect(origin: .zero, size: log.sourceSize).insetBy(dx: -2, dy: -2).contains(point) else { return nil }
        let screen = state.screenRect
        let canvasPerSourcePixel = screen.width / log.sourceSize.width
        return CGPoint(x: screen.minX + point.x * canvasPerSourcePixel, y: screen.minY + point.y * canvasPerSourcePixel)
    }

    private func cursorLayer(_ cursor: CursorImage, tip: CGPoint, screen: CGRect, scale: Double = 1) -> CIImage {
        let canvasPerPoint = screen.width / log.sourceSize.width * log.pointPixelScale * style.cursorScale * scale
        let size = CGSize(width: cursor.size.width * canvasPerPoint, height: cursor.size.height * canvasPerPoint)
        let topLeft = CGPoint(x: tip.x - cursor.hotspot.x * canvasPerPoint, y: tip.y - cursor.hotspot.y * canvasPerPoint)
        let frame = flipped(CGRect(origin: topLeft, size: size))
        return cursor.image.transformed(by: placement(of: cursor.image.extent.size, in: frame))
    }

    /// Equal-weight mean of premultiplied images. CIColorMatrix works on unpremultiplied color,
    /// so scaling alpha alone scales the premultiplied pixel.
    static func average(_ images: [CIImage]) -> CIImage {
        guard images.count > 1 else { return images.first ?? .empty() }
        let weight = CIVector(x: 0, y: 0, z: 0, w: 1 / CGFloat(images.count))
        return images
            .map { $0.applyingFilter("CIColorMatrix", parameters: ["inputAVector": weight]) }
            .reduce(CIImage.empty()) { $1.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: $0]) }
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
