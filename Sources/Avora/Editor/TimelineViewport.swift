import Foundation

/// The stretch of the recording the timeline shows. Zooming in makes short spans wide enough to grab.
@MainActor
final class TimelineViewport: ObservableObject {
    /// Seconds across the timeline at the closest zoom.
    static let minimumSpan = 1.0

    let duration: Double
    @Published private(set) var start = 0.0
    @Published private(set) var span: Double

    init(duration: Double) {
        self.duration = max(duration, 0.001)
        span = self.duration
    }

    var end: Double { start + span }
    var isZoomed: Bool { span < duration - 1e-9 }
    /// 1 shows the whole recording.
    var zoom: Double { duration / span }
    var maxZoom: Double { max(duration / Self.minimumSpan, 1) }

    func x(_ time: Double, width: CGFloat) -> CGFloat {
        CGFloat((time - start) / span) * width
    }

    func time(atX x: CGFloat, width: CGFloat) -> Double {
        start + Double(x / max(width, 1)) * span
    }

    func seconds(perPoint width: CGFloat) -> Double {
        span / Double(max(width, 1))
    }

    /// `factor` above 1 zooms in. The moment at `anchor` keeps its place on screen.
    func zoom(by factor: Double, around anchor: Double) {
        setZoom(zoom * factor, around: anchor)
    }

    func setZoom(_ value: Double, around anchor: Double) {
        let fraction = (anchor - start) / span
        span = duration / min(max(value, 1), maxZoom)
        start = anchor - fraction * span
        clamp()
    }

    func scroll(by seconds: Double) {
        start += seconds
        clamp()
    }

    func scroll(to start: Double) {
        self.start = start
        clamp()
    }

    func fit() {
        span = duration
        start = 0
    }

    /// Pages ahead the way a playing video moves on, so the view jumps rarely instead of sliding.
    func reveal(_ time: Double) {
        guard isZoomed, time < start || time > end - span * 0.02 else { return }
        start = time - span * 0.1
        clamp()
    }

    private func clamp() {
        start = min(max(start, 0), duration - span)
    }
}

enum Snap {
    /// The closest candidate when it is within `tolerance`, otherwise `time` itself.
    static func time(_ time: Double, to candidates: [Double], tolerance: Double) -> Double {
        guard let nearest = candidates.min(by: { abs($0 - time) < abs($1 - time) }),
              abs(nearest - time) <= tolerance else { return time }
        return nearest
    }

    /// A span being moved snaps by whichever of its edges lands closer to a candidate.
    static func start(_ start: Double, length: Double, to candidates: [Double], tolerance: Double) -> Double {
        let end = start + length
        let snappedStart = time(start, to: candidates, tolerance: tolerance)
        let snappedEnd = time(end, to: candidates, tolerance: tolerance)
        switch (snappedStart != start, snappedEnd != end) {
        case (true, true): return abs(snappedStart - start) <= abs(snappedEnd - end) ? snappedStart : snappedEnd - length
        case (true, false): return snappedStart
        case (false, true): return snappedEnd - length
        case (false, false): return start
        }
    }
}

/// Times typed into the inspector: seconds like `2.5` or `2,5`, or clock times like `1:02.25`.
enum TimeText {
    static func parse(_ text: String) -> Double? {
        var cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if cleaned.hasSuffix("s") { cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces) }
        let parts = cleaned.split(separator: ":", omittingEmptySubsequences: false)
        guard !cleaned.isEmpty, parts.count <= 3, let seconds = Double(parts.last!) else { return nil }
        var total = seconds
        for (place, part) in parts.dropLast().reversed().enumerated() {
            guard let whole = Int(part) else { return nil }
            total += Double(whole) * pow(60, Double(place + 1))
        }
        return total
    }

    static func seconds(_ value: Double) -> String {
        String(format: "%.2f s", value)
    }
}
