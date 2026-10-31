import CoreImage
import Testing
@testable import Avora

private func pixel(_ image: CIImage) -> [Float] {
    let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    var value = [Float](repeating: 0, count: 4)
    context.render(image, toBitmap: &value, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
    return value
}

struct MotionBlurTests {
    private let square = CGRect(x: 0, y: 0, width: 2, height: 2)

    @Test func averagingOpaqueAndClearGivesHalfCoverage() {
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: square)
        let clear = CIImage(color: .clear).cropped(to: square)
        let mean = pixel(FrameRenderer.average([red, clear]))
        #expect(abs(mean[0] - 0.5) < 0.001)
        #expect(abs(mean[3] - 0.5) < 0.001)
    }

    @Test func averagingKeepsColorOfIdenticalImages() {
        let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1, alpha: 0.8)).cropped(to: square)
        let mean = pixel(FrameRenderer.average(Array(repeating: blue, count: 4)))
        #expect(abs(mean[2] - 0.8) < 0.001)
        #expect(abs(mean[3] - 0.8) < 0.001)
    }

    @Test func singleImagePassesThrough() {
        let green = CIImage(color: CIColor(red: 0, green: 1, blue: 0)).cropped(to: square)
        #expect(pixel(FrameRenderer.average([green]))[1] == 1)
    }
}
