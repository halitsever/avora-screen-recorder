import CoreGraphics
import Testing
@testable import ZoomEngine

struct FramingTests {
    let base = CGRect(x: 100, y: 50, width: 1000, height: 500)

    @Test func scaleOneKeepsBaseRect() {
        let rect = Framing.zoomedRect(base: base, scale: 1, focus01: CGPoint(x: 0.9, y: 0.1))
        #expect(rect == base)
    }

    @Test func centeredFocusZoomsAroundBaseCenter() {
        let rect = Framing.zoomedRect(base: base, scale: 2, focus01: CGPoint(x: 0.5, y: 0.5))
        #expect(rect.size == CGSize(width: 2000, height: 1000))
        #expect(rect.midX == base.midX)
        #expect(rect.midY == base.midY)
    }

    @Test func focusPointLandsOnBaseCenterWhenRoomAllows() {
        let rect = Framing.zoomedRect(base: base, scale: 2, focus01: CGPoint(x: 0.4, y: 0.6))
        let focus = CGPoint(x: rect.minX + 0.4 * rect.width, y: rect.minY + 0.6 * rect.height)
        #expect(abs(focus.x - base.midX) < 1e-9)
        #expect(abs(focus.y - base.midY) < 1e-9)
    }

    @Test func cornerFocusIsClampedToBaseEdges() {
        let topLeft = Framing.zoomedRect(base: base, scale: 2, focus01: CGPoint(x: 0, y: 0))
        #expect(topLeft.minX == base.minX)
        #expect(topLeft.minY == base.minY)

        let bottomRight = Framing.zoomedRect(base: base, scale: 2, focus01: CGPoint(x: 1, y: 1))
        #expect(bottomRight.maxX == base.maxX)
        #expect(bottomRight.maxY == base.maxY)
    }

    @Test func focusOutsideScreenIsTreatedAsEdge() {
        let rect = Framing.zoomedRect(base: base, scale: 2, focus01: CGPoint(x: -3, y: 0.5))
        #expect(rect.minX == base.minX)
    }
}

struct StageFramingTests {
    // A 16:10 screen resting in the middle of a 9:16 canvas.
    private let stage = CGRect(x: 60, y: 110, width: 960, height: 1700)
    private var base: CGRect { CGRect(x: 60, y: 660, width: 960, height: 600) }

    @Test func zoomGrowsUntilTheStageIsFilled() {
        let rect = Framing.zoomedRect(base: base, scale: 2, focus01: CGPoint(x: 0.5, y: 0.5), stage: stage)
        #expect(rect.height >= stage.height - 0.001)
        #expect(rect.minX <= stage.minX && rect.maxX >= stage.maxX)
        #expect(rect.minY <= stage.minY && rect.maxY >= stage.maxY)
    }

    @Test func zoomBeyondTheFillKeepsItsLevel() {
        let rect = Framing.zoomedRect(base: base, scale: 4, focus01: CGPoint(x: 0.5, y: 0.5), stage: stage)
        #expect(abs(rect.width - base.width * 4) < 0.001)
    }

    @Test func stageEqualToTheBaseChangesNothing() {
        let plain = Framing.zoomedRect(base: base, scale: 2, focus01: CGPoint(x: 0.2, y: 0.7))
        let staged = Framing.zoomedRect(base: base, scale: 2, focus01: CGPoint(x: 0.2, y: 0.7), stage: base)
        #expect(plain == staged)
    }
}
