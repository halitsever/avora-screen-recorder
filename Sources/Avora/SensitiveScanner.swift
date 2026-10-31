import AVFoundation
import Vision

/// Spots text that should not end up in a shared video.
enum SensitiveText {
    /// In order of preference when two kinds claim the same characters.
    enum Kind: CaseIterable { case secret, email, iban, card, phone }

    struct Match {
        var kind: Kind
        var range: Range<String.Index>
    }

    static func matches(in text: String) -> [Match] {
        var found: [Match] = []
        for kind in Kind.allCases {
            for (pattern, valid) in rules[kind] ?? [] {
                for result in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    guard let range = Range(result.range, in: text), valid(String(text[range])),
                          !found.contains(where: { $0.range.overlaps(range) })
                    else { continue }
                    found.append(Match(kind: kind, range: range))
                }
            }
        }
        return found.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private typealias Rule = (NSRegularExpression, (String) -> Bool)

    private static let rules: [Kind: [Rule]] = [
        .secret: [
            rule(#"\b(?:sk|pk|rk)_(?:live|test)_[A-Za-z0-9]{10,}"#),
            rule(#"\bsk-[A-Za-z0-9_-]{20,}"#),
            rule(#"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})"#),
            rule(#"\bxox[abprs]-[A-Za-z0-9-]{10,}"#),
            rule(#"\bAKIA[0-9A-Z]{16}\b"#),
            rule(#"\bAIza[0-9A-Za-z_-]{35}\b"#),
            rule(#"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#),
            // Any long run mixing cases and digits reads like a generated token, not a word.
            rule(#"\b[A-Za-z0-9_-]{32,}\b"#) { token in
                token.contains(where: \.isUppercase) && token.contains(where: \.isLowercase) && token.contains(where: \.isNumber)
            },
        ],
        .email: [rule(#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)],
        .iban: [rule(#"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){2,7}(?: ?[A-Z0-9]{1,3})?\b"#, valid: ibanChecksum)],
        .card: [rule(#"\b(?:\d[ -]?){12,18}\d\b"#, valid: luhn)],
        .phone: [
            rule(#"\+\d{1,3}[ .-]?\(?\d{1,4}\)?(?:[ .-]?\d{2,4}){2,4}\b"#, valid: phoneLength),
            rule(#"\(\d{3}\) ?\d{3}[ .-]\d{4}\b"#),
            rule(#"\b\d{3}[.-]\d{3}[.-]\d{4}\b"#),
            rule(#"\b0\d{3} ?\d{3} ?\d{2} ?\d{2}\b"#),
        ],
    ]

    private static func rule(_ pattern: String, valid: @escaping (String) -> Bool = { _ in true }) -> Rule {
        (try! NSRegularExpression(pattern: pattern), valid)
    }

    private static func digits(_ text: String) -> [Int] {
        text.compactMap(\.wholeNumberValue)
    }

    static func luhn(_ text: String) -> Bool {
        let digits = digits(text)
        guard (13...19).contains(digits.count), Set(digits).count > 1 else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { sum, entry in
            let doubled = entry.offset % 2 == 1 ? entry.element * 2 : entry.element
            return sum + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum % 10 == 0
    }

    static func ibanChecksum(_ text: String) -> Bool {
        let compact = text.filter { $0 != " " }
        guard (15...34).contains(compact.count) else { return false }
        let rearranged = compact.dropFirst(4) + compact.prefix(4)
        var remainder = 0
        for character in rearranged {
            guard let value = character.wholeNumberValue ?? character.asciiValue.map({ Int($0) - 55 }) else { return false }
            for digit in String(value) { remainder = (remainder * 10 + digit.wholeNumberValue!) % 97 }
        }
        return remainder == 1
    }

    private static func phoneLength(_ text: String) -> Bool {
        (9...15).contains(digits(text).count)
    }
}

/// Finds private things on screen with Vision and turns them into blur masks.
enum SensitiveScanner {
    enum Target {
        case text, faces

        /// Seconds between the frames read. Text sits still long enough for a slower pace.
        var interval: Double { self == .text ? 1 : 0.5 }
    }

    typealias Sighting = (time: Double, rect: CGRect)

    /// Joins sightings of one thing in nearby frames into a single blur. Each blur starts and ends
    /// one frame early and late, since the thing may have shown up between two frames.
    static func masks(from sightings: [Sighting], interval: Double, duration: Double, grow: Double = 0.3) -> [Mask] {
        var tracks: [(first: Double, last: Double, area: CGRect, latest: CGRect)] = []
        for sighting in sightings.sorted(by: { $0.time < $1.time }) {
            if let index = tracks.lastIndex(where: {
                sighting.time - $0.last <= interval * 1.5 + 1e-9 && overlap($0.latest, sighting.rect) > 0.5
            }) {
                tracks[index].last = sighting.time
                tracks[index].area = tracks[index].area.union(sighting.rect)
                tracks[index].latest = sighting.rect
            } else {
                tracks.append((sighting.time, sighting.time, sighting.rect, sighting.rect))
            }
        }
        let frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        return tracks.map { track in
            let pad = max(0.004, track.area.height * grow)
            return Mask(start: max(0, track.first - interval), end: min(duration, track.last + interval),
                        rect: track.area.insetBy(dx: -pad, dy: -pad).intersection(frame), kind: .blur)
        }
    }

    /// Reads the recording a frame per `target.interval`. A frame that looks the same as the one
    /// before it reuses that frame's findings, which saves most of the work on a still screen.
    static func scan(_ video: URL, duration: Double, for target: Target,
                     progress: @escaping @Sendable (Double) -> Void) async throws -> [Mask] {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.requestedTimeToleranceBefore = .seconds(target.interval / 4)
        generator.requestedTimeToleranceAfter = .seconds(target.interval / 4)
        let times = stride(from: 0, to: duration, by: target.interval).map { CMTime.seconds($0) }
        var sightings: [Sighting] = []
        var previous: (thumbnail: [UInt8], found: [CGRect])?
        for await result in generator.images(for: times) {
            try Task.checkCancellation()
            guard case .success(let requested, let image, _) = result else { continue }
            let thumbnail = thumbnail(image)
            let found: [CGRect]
            if let previous, zip(previous.thumbnail, thumbnail).allSatisfy({ abs(Int($0) - Int($1)) <= 8 }) {
                found = previous.found
            } else {
                found = try detect(target, in: image)
            }
            sightings += found.map { (requested.seconds, $0) }
            previous = (thumbnail, found)
            progress(min(requested.seconds / duration, 1))
        }
        return masks(from: sightings, interval: target.interval, duration: duration, grow: target == .text ? 0.3 : 0.25)
    }

    /// Areas as fractions of the frame with a top-left origin, like a mask's.
    static func detect(_ target: Target, in image: CGImage) throws -> [CGRect] {
        let handler = VNImageRequestHandler(cgImage: image)
        let boxes: [CGRect]
        switch target {
        case .text:
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Correction would "fix" keys and addresses into words.
            request.usesLanguageCorrection = false
            try handler.perform([request])
            boxes = (request.results ?? []).flatMap { observation -> [CGRect] in
                guard let line = observation.topCandidates(1).first else { return [] }
                return SensitiveText.matches(in: line.string).compactMap { try? line.boundingBox(for: $0.range)?.boundingBox }
            }
        case .faces:
            let request = VNDetectFaceRectanglesRequest()
            try handler.perform([request])
            boxes = (request.results ?? []).map(\.boundingBox)
        }
        return boxes.map { CGRect(x: $0.minX, y: 1 - $0.maxY, width: $0.width, height: $0.height) }
    }

    private static func overlap(_ a: CGRect, _ b: CGRect) -> Double {
        let shared = a.intersection(b)
        guard !shared.isNull else { return 0 }
        let common = shared.width * shared.height
        return common / (a.width * a.height + b.width * b.height - common)
    }

    /// A small grey copy of the frame, enough to tell whether anything changed.
    private static func thumbnail(_ image: CGImage) -> [UInt8] {
        let width = 160, height = 100
        var pixels = [UInt8](repeating: 0, count: width * height)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }
}
