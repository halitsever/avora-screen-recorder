import CoreGraphics

public struct TimedPoint: Sendable, Equatable {
    public var time: Double
    public var position: CGPoint
    public var isClick: Bool

    public init(time: Double, position: CGPoint, isClick: Bool) {
        self.time = time
        self.position = position
        self.isClick = isClick
    }
}

public struct FocusCluster: Sendable, Equatable {
    public var start: Double
    public var center: CGPoint
}

/// Groups cursor activity into regions so the camera holds still while the cursor stays in one area.
public enum FocusPlanner {
    /// Dwell time given to the very last point, which has no successor to measure against.
    static let tailDwell = 0.1

    public static func thin(_ points: [TimedPoint], minDistance: Double) -> [TimedPoint] {
        var kept: [TimedPoint] = []
        for point in points {
            guard let last = kept.last, !point.isClick else {
                kept.append(point)
                continue
            }
            if hypot(point.position.x - last.position.x, point.position.y - last.position.y) >= minDistance {
                kept.append(point)
            }
        }
        return kept
    }

    /// Greedy grouping: a cluster grows until its bounding box would exceed `maxSpan`.
    public static func clusters(_ points: [TimedPoint], maxSpan: CGSize) -> [FocusCluster] {
        var groups: [[TimedPoint]] = []
        var bounds = CGRect.null
        for point in points {
            let grown = bounds.union(CGRect(origin: point.position, size: .zero))
            if groups.isEmpty || grown.width > maxSpan.width || grown.height > maxSpan.height {
                groups.append([point])
                bounds = CGRect(origin: point.position, size: .zero)
            } else {
                groups[groups.count - 1].append(point)
                bounds = grown
            }
        }

        return groups.enumerated().map { index, group in
            let finish = index + 1 < groups.count ? groups[index + 1][0].time : nil
            return FocusCluster(start: group[0].time, center: dwellWeightedCenter(group, finish: finish))
        }
    }

    public static func focus(at time: Double, in clusters: [FocusCluster]) -> CGPoint? {
        (clusters.last { $0.start <= time } ?? clusters.first)?.center
    }

    /// Half of the source area that stays visible at `scale`, so a cluster always fits on screen with margin.
    public static func clusterSpan(sourceSize: CGSize, scale: Double) -> CGSize {
        let scale = max(scale, 1)
        return CGSize(width: sourceSize.width / scale / 2, height: sourceSize.height / scale / 2)
    }

    static func dwellWeightedCenter(_ points: [TimedPoint], finish: Double?) -> CGPoint {
        var total = 0.0, x = 0.0, y = 0.0
        for (index, point) in points.enumerated() {
            let next = index + 1 < points.count ? points[index + 1].time : (finish ?? point.time + tailDwell)
            let weight = max(next - point.time, 0)
            total += weight
            x += point.position.x * weight
            y += point.position.y * weight
        }
        guard total > 0 else {
            let count = Double(points.count)
            return CGPoint(
                x: points.reduce(0) { $0 + $1.position.x } / count,
                y: points.reduce(0) { $0 + $1.position.y } / count
            )
        }
        return CGPoint(x: x / total, y: y / total)
    }
}
