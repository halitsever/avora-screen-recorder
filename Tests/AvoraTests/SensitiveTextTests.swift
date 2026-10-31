import AVFoundation
import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import Avora

struct SensitiveTextTests {
    @Test func findsTheUsualSuspects() {
        #expect(SensitiveText.matches(in: "mail me at jane.doe@example.com today").map(\.kind) == [.email])
        #expect(SensitiveText.matches(in: "Call +90 532 123 45 67").map(\.kind) == [.phone])
        #expect(SensitiveText.matches(in: "Card 4242 4242 4242 4242 exp").map(\.kind) == [.card])
        #expect(SensitiveText.matches(in: "IBAN TR33 0006 1005 1978 6457 8413 26").map(\.kind) == [.iban])
        // Split so push protection doesn't take the made-up key for a real one.
        #expect(SensitiveText.matches(in: "key sk_" + "live_51HxYzAbCdEfGhIjKlMnOpQr").map(\.kind) == [.secret])
        #expect(SensitiveText.matches(in: "AKIAIOSFODNN7EXAMPLE").map(\.kind) == [.secret])
    }

    @Test func matchCoversOnlyTheSensitivePart() throws {
        let text = "mail me at jane@example.com today"
        let match = try #require(SensitiveText.matches(in: text).first)
        #expect(String(text[match.range]) == "jane@example.com")
    }

    @Test func ordinaryNumbersAreLeftAlone() {
        #expect(SensitiveText.matches(in: "Order 1234 5678 9012 3456 shipped").isEmpty)
        #expect(SensitiveText.matches(in: "Version 2026.10.31 build 5005").isEmpty)
        #expect(SensitiveText.matches(in: "Hello world, nothing private here").isEmpty)
    }

    @Test func repeatedSightingsBecomeOneMask() {
        let box = CGRect(x: 0.2, y: 0.3, width: 0.2, height: 0.04)
        let found = [
            (time: 1.0, rect: box), (time: 2.0, rect: box.offsetBy(dx: 0.005, dy: 0)), (time: 3.0, rect: box),
            (time: 3.0, rect: CGRect(x: 0.6, y: 0.7, width: 0.1, height: 0.05)),
        ]
        let masks = SensitiveScanner.masks(from: found, interval: 1, duration: 10)
        #expect(masks.count == 2)
        let first = masks.first { $0.rect.minX < 0.5 }!
        #expect(first.start <= 1 && first.end >= 3)
        #expect(first.rect.contains(box))
        #expect(masks.allSatisfy { $0.kind == .blur })
    }

    @Test func visionFindsTheAddressWhereItIsDrawn() throws {
        let width = 1600, height = 1000
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let font = NSFont.systemFont(ofSize: 40)
        NSAttributedString(string: "Contact: jane.doe@example.com", attributes: [.font: font, .foregroundColor: NSColor.black])
            .draw(at: CGPoint(x: 100, y: 800))
        NSAttributedString(string: "Nothing to hide down here", attributes: [.font: font, .foregroundColor: NSColor.black])
            .draw(at: CGPoint(x: 100, y: 200))
        NSGraphicsContext.restoreGraphicsState()
        let image = try #require(context.makeImage())

        let boxes = try SensitiveScanner.detect(.text, in: image)
        #expect(boxes.count == 1)
        let box = try #require(boxes.first)
        // Drawn 800 pt up from the bottom, so near the top in a top-left frame.
        #expect(box.minY < 0.2)
        #expect(box.minX > 0.15)
    }

    @Test func scanningAVideoBlursTheAddressWhileItIsShown() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "avora-scan-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: url) }
        let width = 1280, height = 800, fps = 4
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<(4 * fps) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            let context = try #require(CGContext(
                data: CVPixelBufferGetBaseAddress(pixels), width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixels), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))
            context.setFillColor(.white)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            // Shown from 0.75 s to 2.25 s, so both frames read near 1 s and 2 s carry it.
            if (3...8).contains(frame) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
                NSAttributedString(string: "jane.doe@example.com", attributes: [.font: NSFont.systemFont(ofSize: 36), .foregroundColor: NSColor.black])
                    .draw(at: CGPoint(x: 400, y: 600))
                NSGraphicsContext.restoreGraphicsState()
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
            adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps)))
        }
        input.markAsFinished()
        await writer.finishWriting()

        let masks = try await SensitiveScanner.scan(url, duration: 4, for: .text) { _ in }
        #expect(masks.count == 1)
        let mask = try #require(masks.first)
        #expect(mask.start <= 0.75 && mask.end >= 2.25)
        #expect(mask.end <= 3.5)
        #expect(mask.rect.minY < 0.25 && mask.rect.minX > 0.25)
    }
}
