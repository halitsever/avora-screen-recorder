import CoreImage
import Testing
@testable import Avora

/// Renders `image` and returns the sRGB color at `point`, measured from the top-left corner.
private func pixel(_ image: CIImage, at point: CGPoint) -> (r: Int, g: Int, b: Int) {
    var rgba = [UInt8](repeating: 0, count: 4)
    let y = image.extent.height - 1 - point.y
    CIContext().render(image, toBitmap: &rgba, rowBytes: 4,
                       bounds: CGRect(x: point.x, y: y, width: 1, height: 1),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    return (Int(rgba[0]), Int(rgba[1]), Int(rgba[2]))
}

private func isClose(_ color: (r: Int, g: Int, b: Int), to hex: UInt32, tolerance: Int = 14) -> Bool {
    abs(color.r - Int(hex >> 16 & 0xFF)) <= tolerance
        && abs(color.g - Int(hex >> 8 & 0xFF)) <= tolerance
        && abs(color.b - Int(hex & 0xFF)) <= tolerance
}

struct BackgroundPresetTests {
    @Test func catalogHasTwelveUniquePresets() {
        let ids = BackgroundPreset.all.map(\.id)
        #expect(ids.count == 12)
        #expect(Set(ids).count == ids.count)
    }

    @Test func avoraIsTheDefault() {
        #expect(BackgroundPreset.named(nil).id == "avora")
    }

    @Test func unknownIDFallsBackToDefault() {
        #expect(BackgroundPreset.named("no-such-background").id == "avora")
    }

    @Test func knownIDIsFound() {
        #expect(BackgroundPreset.named("sky").name == "Sky")
    }

    @Test func everyPresetFillsTheRequestedSize() {
        let size = CGSize(width: 320, height: 200)
        for preset in BackgroundPreset.all {
            #expect(preset.image(size: size).extent == CGRect(origin: .zero, size: size), "\(preset.id)")
        }
    }

    @Test func linearGradientRunsFromTopLeftToBottomRight() {
        let image = BackgroundPreset.named("avora").image(size: CGSize(width: 100, height: 100))
        #expect(isClose(pixel(image, at: CGPoint(x: 0, y: 0)), to: 0xF26B1D))
        #expect(isClose(pixel(image, at: CGPoint(x: 99, y: 99)), to: 0xFFD3A1))
    }

    @Test func radialGradientIsLightestNearItsCenter() {
        let image = BackgroundPreset.named("studio").image(size: CGSize(width: 200, height: 100))
        let center = pixel(image, at: CGPoint(x: 100, y: 30))
        let corner = pixel(image, at: CGPoint(x: 0, y: 99))
        #expect(center.r + center.g + center.b > corner.r + corner.g + corner.b)
        #expect(isClose(corner, to: 0x15151A))
    }
}
