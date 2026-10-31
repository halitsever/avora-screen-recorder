import CoreImage
import Foundation
import Testing
import ZoomEngine
@testable import Avora

private func pixel(_ image: CIImage, at point: CGPoint) -> [Float] {
    let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    var value = [Float](repeating: 0, count: 4)
    context.render(image, toBitmap: &value, rowBytes: 16, bounds: CGRect(origin: point, size: CGSize(width: 1, height: 1)), format: .RGBAf, colorSpace: nil)
    return value
}

/// White on the left half, black on the right, 200 by 100.
private func halves() -> CIImage {
    let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
    let black = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: CGRect(x: 100, y: 0, width: 100, height: 100))
    return white.composited(over: black)
}

struct MaskTests {
    @Test func masksAreSavedWithTheEdits() throws {
        let folder = RecordingFolder(url: FileManager.default.temporaryDirectory.appending(path: "avora-mask-\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let mask = Mask(start: 1, end: 3, rect: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.1), kind: .blur)
        try folder.save(RecordingEdits(masks: [mask]))
        #expect(folder.loadEdits()?.masks == [mask])
    }

    @Test func blurSmearsOnlyInsideTheMask() {
        // The mask straddles the white/black border in the middle; rects use a top-left origin.
        let mask = Mask(start: 0, end: 1, rect: CGRect(x: 0.4, y: 0, width: 0.2, height: 0.5), kind: .blur)
        let masked = Masking.apply([mask], to: halves(), at: 0.5)
        let inside = pixel(masked, at: CGPoint(x: 98, y: 75))
        #expect(inside[0] < 0.95 && inside[0] > 0.05)
        #expect(pixel(masked, at: CGPoint(x: 98, y: 25))[0] > 0.99)
    }

    @Test func highlightDimsEverythingElse() {
        let mask = Mask(start: 0, end: 1, rect: CGRect(x: 0, y: 0, width: 0.25, height: 1), kind: .highlight)
        let masked = Masking.apply([mask], to: halves(), at: 0.5)
        #expect(pixel(masked, at: CGPoint(x: 20, y: 50))[0] > 0.99)
        #expect(pixel(masked, at: CGPoint(x: 70, y: 50))[0] < 0.6)
    }

    @Test func masksOnlyActInTheirTimeRange() {
        let mask = Mask(start: 2, end: 3, rect: CGRect(x: 0, y: 0, width: 0.25, height: 1), kind: .highlight)
        #expect(pixel(Masking.apply([mask], to: halves(), at: 1), at: CGPoint(x: 70, y: 50))[0] > 0.99)
    }
}

struct MaskCoverageTests {
    @Test func aBiggerLongerBlurCoversASmallerOne() {
        let big = Mask(start: 1, end: 9, rect: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5), kind: .blur)
        let inside = Mask(start: 2, end: 8, rect: CGRect(x: 0.2, y: 0.2, width: 0.1, height: 0.1), kind: .blur)
        let later = Mask(start: 5, end: 12, rect: inside.rect, kind: .blur)
        let elsewhere = Mask(start: 2, end: 8, rect: CGRect(x: 0.7, y: 0.7, width: 0.1, height: 0.1), kind: .blur)
        #expect(big.covers(inside))
        #expect(!big.covers(later))
        #expect(!big.covers(elsewhere))
    }
}
