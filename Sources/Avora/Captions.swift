import AppKit
import CoreImage
import Speech
import ZoomEngine

/// One line of captions on the recording's timeline.
struct Caption: TimeSpan, Codable {
    var start: Double
    var end: Double
    var text: String
}

/// A recognized word; times are in the recording.
struct SpokenWord: Equatable {
    var text: String
    var start: Double
    var end: Double
}

enum CaptionError: LocalizedError {
    case noSound
    case denied
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .noSound: "This recording has no sound to turn into captions."
        case .denied: "Avora needs Speech Recognition permission to write captions. Enable it in System Settings > Privacy & Security > Speech Recognition."
        case .unavailable(let language): "Captions in \(language) can't be made on this Mac. Pick another language in Avora's settings."
        }
    }
}

enum Captioner {
    static let maxWords = 7
    static let maxLength = 3.0
    static let pause = 0.6
    /// How long a line stays after its last word, unless the next line starts sooner.
    static let hold = 0.3

    /// Short lines that are easy to read: a few words at most, broken at pauses and sentence ends.
    static func phrases(from words: [SpokenWord]) -> [Caption] {
        var groups: [[SpokenWord]] = []
        for word in words {
            if let current = groups.last, let first = current.first, let last = current.last,
               current.count < maxWords, word.start - last.end <= pause, word.end - first.start <= maxLength,
               !last.text.hasSuffix("."), !last.text.hasSuffix("?"), !last.text.hasSuffix("!") {
                groups[groups.count - 1].append(word)
            } else {
                groups.append([word])
            }
        }
        return groups.enumerated().map { index, group in
            let next = index + 1 < groups.count ? groups[index + 1].first!.start : .infinity
            return Caption(start: group.first!.start, end: min(group.last!.end + hold, next), text: group.map(\.text).joined(separator: " "))
        }
    }

    /// Captions for the voice, or the Mac's sound when no microphone was recorded. Recognition
    /// runs on this Mac whenever the language supports it.
    static func transcribe(_ folder: RecordingFolder, locale: Locale) async throws -> [Caption] {
        guard let data = try? Data(contentsOf: folder.audioManifest),
              let manifest = try? JSONDecoder().decode(AudioManifest.self, from: data),
              let track = manifest.tracks.first(where: { $0.kind == .microphone }) ?? manifest.tracks.first
        else { throw CaptionError.noSound }

        let status = await withCheckedContinuation { done in SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0) } }
        guard status == .authorized else { throw CaptionError.denied }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw CaptionError.unavailable(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
        }

        let request = SFSpeechURLRecognitionRequest(url: folder.url.appending(path: track.file))
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        let segments: [SFTranscriptionSegment] = try await withCheckedThrowingContinuation { done in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let result, result.isFinal {
                    finished = true
                    done.resume(returning: result.bestTranscription.segments)
                } else if let error {
                    finished = true
                    done.resume(throwing: error)
                }
            }
        }
        return phrases(from: segments.map {
            SpokenWord(text: $0.substring, start: $0.timestamp + track.offset, end: $0.timestamp + $0.duration + track.offset)
        })
    }
}

/// Captions as an .srt file, timed to the edited video.
enum SubRip {
    static func make(_ captions: [Caption], clips: ClipList) -> String {
        captions.compactMap { caption -> (Double, Double, String)? in
            let start = clips.outputTime(snappingSource: caption.start)
            let end = clips.outputTime(snappingSource: caption.end)
            return end > start ? (start, end, caption.text) : nil
        }
        .enumerated()
        .map { index, entry in "\(index + 1)\n\(stamp(entry.0)) --> \(stamp(entry.1))\n\(entry.2)\n" }
        .joined(separator: "\n")
    }

    private static func stamp(_ seconds: Double) -> String {
        let millis = Int((seconds * 1000).rounded())
        return String(format: "%02d:%02d:%02d,%03d", millis / 3_600_000, millis / 60000 % 60, millis / 1000 % 60, millis % 1000)
    }
}

/// Burned-in captions: white text on a dark pill, wrapped to a readable width.
enum CaptionOverlay {
    static func badge(_ text: String, canvas: CGSize) -> CIImage {
        let font = NSFont.systemFont(ofSize: canvas.height * 0.042, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
        let maxWidth = canvas.width * 0.7
        let measured = string.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                           options: [.usesLineFragmentOrigin, .usesFontLeading])
        let pad = CGSize(width: font.pointSize * 0.7, height: font.pointSize * 0.4)
        let size = CGSize(width: ceil(measured.width + pad.width * 2), height: ceil(measured.height + pad.height * 2))
        guard size.width > 0, size.height > 0,
              let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return .empty() }
        let radius = min(size.height / 2, font.pointSize * 0.8)
        context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.setFillColor(CGColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 0.82))
        context.fillPath()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        string.draw(with: CGRect(x: pad.width, y: pad.height, width: measured.width, height: measured.height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage().map { CIImage(cgImage: $0) } ?? .empty()
    }
}
