import CoreImage
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Avora

private func centerPixel(_ image: CIImage, in size: CGSize) -> [Float] {
    let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    var value = [Float](repeating: 0, count: 4)
    context.render(image, toBitmap: &value, rowBytes: 16, bounds: CGRect(x: size.width / 2, y: size.height / 2, width: 1, height: 1),
                   format: .RGBAf, colorSpace: nil)
    return value
}

struct CustomBackgroundTests {
    @Test func colorIDsMakeASolidBackdrop() {
        let preset = BackgroundPreset.named("color:FF0000")
        #expect(preset.fill == .solid(RGB(0xFF0000)))
        let pixel = centerPixel(preset.image(size: CGSize(width: 10, height: 10)), in: CGSize(width: 10, height: 10))
        #expect(pixel[0] > 0.99 && pixel[1] < 0.01)
    }

    @Test func badColorFallsBackToTheDefault() {
        #expect(BackgroundPreset.named("color:nothex").id == BackgroundPreset.defaultID)
    }

    @Test func imageIDsAreNamedAfterTheFile() {
        let preset = BackgroundPreset.named("image:/tmp/Beach Day.png")
        #expect(preset.name == "Beach Day")
        #expect(preset.fill == .image(URL(fileURLWithPath: "/tmp/Beach Day.png")))
    }

    @Test func imagesFillTheWholeCanvas() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "avora-bg-\(UUID().uuidString).png")
        let context = CGContext(data: nil, width: 40, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 10))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)

        let size = CGSize(width: 100, height: 100)
        let image = BackgroundPreset.named("image:\(url.path)").image(size: size)
        #expect(image.extent == CGRect(origin: .zero, size: size))
        #expect(centerPixel(image, in: size)[2] > 0.99)
    }

    @Test func missingImageStillDrawsSomething() {
        let size = CGSize(width: 20, height: 20)
        let image = BackgroundPreset.named("image:/nonexistent/file.png").image(size: size)
        #expect(image.extent == CGRect(origin: .zero, size: size))
    }
}
