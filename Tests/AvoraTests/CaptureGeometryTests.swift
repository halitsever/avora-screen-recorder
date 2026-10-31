import CoreGraphics
import Testing
@testable import Avora

struct CaptureGeometryTests {
    private let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let side = CGRect(x: 1512, y: -200, width: 1920, height: 1080)

    @Test func cocoaRectsFlipAroundTheMainDisplay() {
        let cocoa = CGRect(x: 100, y: 700, width: 300, height: 200)
        #expect(CaptureGeometry.globalRect(fromCocoa: cocoa, mainHeight: 982) == CGRect(x: 100, y: 82, width: 300, height: 200))
        #expect(CaptureGeometry.cocoaRect(fromGlobal: CGRect(x: 100, y: 82, width: 300, height: 200), mainHeight: 982) == cocoa)
    }

    @Test func dragInAnyDirectionGivesTheSameArea() {
        let a = CaptureGeometry.selection(from: CGPoint(x: 500, y: 400), to: CGPoint(x: 200, y: 100), within: main)
        #expect(a == CGRect(x: 200, y: 100, width: 300, height: 300))
    }

    @Test func selectionStaysOnItsDisplay() {
        let area = CaptureGeometry.selection(from: CGPoint(x: 1300, y: 800), to: CGPoint(x: 1700, y: 1100), within: main)
        #expect(area == CGRect(x: 1300, y: 800, width: 212, height: 182))
    }

    @Test func tinySelectionsAreRejected() {
        #expect(CaptureGeometry.selection(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 100, y: 400), within: main) == nil)
    }

    @Test func areaIsCapturedFromTheDisplayItOverlapsMost() {
        let area = CGRect(x: 1400, y: 100, width: 400, height: 300)
        #expect(CaptureGeometry.bestDisplay(for: area, among: [main, side]) == 1)
    }

    @Test func sourceRectIsRelativeToTheDisplay() {
        let area = CGRect(x: 1600, y: 0, width: 400, height: 300)
        #expect(CaptureGeometry.sourceRect(for: area, on: side) == CGRect(x: 88, y: 200, width: 400, height: 300))
    }

    @Test func pixelSizeIsEvenForTheEncoder() {
        #expect(CaptureGeometry.pixelSize(for: CGRect(x: 0, y: 0, width: 301.5, height: 201), scale: 2) == CGSize(width: 602, height: 402))
        #expect(CaptureGeometry.pixelSize(for: CGRect(x: 0, y: 0, width: 300.75, height: 200), scale: 1) == CGSize(width: 300, height: 200))
    }

    @Test func cursorFollowsAMovedWindow() {
        let pixels = CGSize(width: 1600, height: 1000)
        let start = CGRect(x: 100, y: 100, width: 800, height: 500)
        #expect(CaptureGeometry.pixel(for: CGPoint(x: 500, y: 350), in: start, pixelSize: pixels) == CGPoint(x: 800, y: 500))
        let moved = start.offsetBy(dx: 300, dy: 50)
        #expect(CaptureGeometry.pixel(for: CGPoint(x: 800, y: 400), in: moved, pixelSize: pixels) == CGPoint(x: 800, y: 500))
    }

    @Test func cursorScalesWithAResizedWindow() {
        let pixels = CGSize(width: 1600, height: 1000)
        let bigger = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        #expect(CaptureGeometry.pixel(for: CGPoint(x: 800, y: 500), in: bigger, pixelSize: pixels) == CGPoint(x: 800, y: 500))
    }
}
