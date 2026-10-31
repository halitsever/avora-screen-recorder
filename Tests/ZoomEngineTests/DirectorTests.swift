import CoreGraphics
import Testing
@testable import ZoomEngine

private let source = CGSize(width: 2000, height: 1000)
private let base = CGRect(x: 100, y: 50, width: 1000, height: 500)
private let fps = 60.0

private func frame(_ frames: [FrameState], at time: Double) throws -> FrameState {
    let index = Int((time * fps).rounded())
    try #require(frames.indices.contains(index), "no frame at \(time)s")
    return frames[index]
}

private func log(duration: Double, cursor: [CursorSample], clicks: [ClickEvent] = []) -> InputLog {
    InputLog(sourceSize: source, pointPixelScale: 2, duration: duration, cursor: cursor, clicks: clicks)
}

struct DirectorTests {
    @Test func producesOneFramePerTick() throws {
        let director = Director(log: log(duration: 2, cursor: []), base: base)
        #expect(director.frames(fps: fps).count == 120)
    }

    @Test func withoutClicksScreenNeverZooms() throws {
        let cursor = [CursorSample(time: 0, position: CGPoint(x: 500, y: 500))]
        let frames = Director(log: log(duration: 5, cursor: cursor), base: base).frames(fps: fps)
        #expect(frames.allSatisfy { $0.screenRect == base })
    }

    @Test func clickZoomsInThenBackOut() throws {
        let center = CGPoint(x: 1000, y: 500)
        let cursor = [CursorSample(time: 0, position: center)]
        let clicks = [ClickEvent(time: 2, position: center, isDown: true)]
        let frames = Director(log: log(duration: 12, cursor: cursor, clicks: clicks), base: base).frames(fps: fps)

        #expect(try frame(frames, at: 1).screenRect == base)
        #expect(abs(try frame(frames, at: 4).screenRect.width - 2000) < 20)
        #expect(abs(try frame(frames, at: 11.5).screenRect.width - 1000) < 1)
    }

    @Test func zoomFollowsWhereTheCursorIs() throws {
        let corner = CGPoint(x: 10, y: 10)
        let cursor = [CursorSample(time: 0, position: corner)]
        let clicks = [ClickEvent(time: 2, position: corner, isDown: true)]
        let frames = Director(log: log(duration: 12, cursor: cursor, clicks: clicks), base: base).frames(fps: fps)

        let zoomed = try frame(frames, at: 4).screenRect
        #expect(abs(zoomed.minX - base.minX) < 1)
        #expect(abs(zoomed.minY - base.minY) < 1)
    }

    @Test func cursorGlidesInsteadOfTeleporting() throws {
        let cursor = [
            CursorSample(time: 0, position: CGPoint(x: 0, y: 0)),
            CursorSample(time: 1, position: CGPoint(x: 0, y: 0)),
            CursorSample(time: 1.001, position: CGPoint(x: 1000, y: 0)),
        ]
        let frames = Director(log: log(duration: 4, cursor: cursor), base: base).frames(fps: fps)
        let shortlyAfter = try #require(try frame(frames, at: 1.05).cursor)
        let later = try #require(try frame(frames, at: 3).cursor)
        #expect(shortlyAfter.x > 0 && shortlyAfter.x < 1000)
        #expect(abs(later.x - 1000) < 1)
    }

    @Test func cursorPositionIsInterpolatedBetweenSamples() throws {
        let samples = [
            CursorSample(time: 0, position: CGPoint(x: 0, y: 0)),
            CursorSample(time: 1, position: CGPoint(x: 100, y: 50)),
        ]
        #expect(Director.rawCursor(at: 0.5, in: samples) == CGPoint(x: 50, y: 25))
        #expect(Director.rawCursor(at: 5, in: samples) == CGPoint(x: 100, y: 50))
        #expect(Director.rawCursor(at: -1, in: samples) == CGPoint(x: 0, y: 0))
    }

    @Test func cursorShapeComesFromLatestSample() throws {
        let cursor = [
            CursorSample(time: 0, position: .zero, shape: 0),
            CursorSample(time: 1, position: .zero, shape: 3),
        ]
        let frames = Director(log: log(duration: 2, cursor: cursor), base: base).frames(fps: fps)
        #expect(try frame(frames, at: 0.5).cursorShape == 0)
        #expect(try frame(frames, at: 1.5).cursorShape == 3)
    }
}

struct DirectorSmoothingTests {
    @Test func withoutCursorSpringTheCursorIsTheRawPosition() {
        let log = InputLog(
            sourceSize: CGSize(width: 1000, height: 600), pointPixelScale: 1, duration: 1,
            cursor: [CursorSample(time: 0, position: CGPoint(x: 0, y: 0)), CursorSample(time: 1, position: CGPoint(x: 600, y: 0))],
            clicks: []
        )
        let frames = Director(log: log, base: CGRect(x: 0, y: 0, width: 1000, height: 600), cursorSpring: nil).frames(fps: 10)
        #expect(frames[5].cursor == CGPoint(x: 300, y: 0))
    }
}
