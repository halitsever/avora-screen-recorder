import CoreImage
import ZoomEngine

/// A part of the recording blurred out, or kept bright while the rest dims, for a while.
struct Mask: TimeSpan, Codable {
    enum Kind: String, Codable, CaseIterable { case blur, highlight }

    var start: Double
    var end: Double
    /// Fractions of the recorded frame with a top-left origin.
    var rect: CGRect
    var kind: Kind

    /// True when this mask already hides `other` for its whole time.
    func covers(_ other: Mask) -> Bool {
        start <= other.start + 0.05 && end >= other.end - 0.05 && rect.insetBy(dx: -0.01, dy: -0.01).contains(other.rect)
    }
}

enum Masking {
    /// Seconds a mask takes to fade in at its start and out at its end.
    static let fade = 0.2

    /// `source` is a recorded frame with its origin at zero; `time` is in the recording.
    static func apply(_ masks: [Mask], to source: CIImage, at time: Double) -> CIImage {
        let size = source.extent.size
        return masks.filter { $0.contains(time) }.reduce(source) { image, mask in
            let strength = min(1, (time - mask.start) / fade, (mask.end - time) / fade)
            let area = CGRect(x: mask.rect.minX * size.width, y: (1 - mask.rect.maxY) * size.height,
                              width: mask.rect.width * size.width, height: mask.rect.height * size.height)
            switch mask.kind {
            case .blur:
                // Strong enough that text under it cannot be read back.
                let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: max(size.width, size.height) * 0.012).cropped(to: area)
                return fadeIn(blurred, strength).composited(over: image)
            case .highlight:
                let dim = 1 - 0.55 * strength
                let dimmed = image.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: dim, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: dim, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: dim, w: 0),
                ])
                return image.cropped(to: area).composited(over: dimmed)
            }
        }
    }

    private static func fadeIn(_ image: CIImage, _ strength: Double) -> CIImage {
        guard strength < 1 else { return image }
        return image.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: strength)])
    }
}
