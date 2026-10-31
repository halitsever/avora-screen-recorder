import AVFoundation
import AppKit
import CoreImage
import SwiftUI

/// Carries the renderer to the compositor; AVFoundation creates the compositor itself.
/// Nothing in it changes after creation, so sharing it across threads is safe.
final class PreviewInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let renderer: FrameRenderer
    let sourceTrackID: CMPersistentTrackID

    init(timeRange: CMTimeRange, renderer: FrameRenderer, sourceTrackID: CMPersistentTrackID) {
        self.timeRange = timeRange
        self.renderer = renderer
        self.sourceTrackID = sourceTrackID
        requiredSourceTrackIDs = [NSNumber(value: sourceTrackID)]
    }
}

/// Draws preview frames with the same renderer as export, so what plays is what gets saved.
final class PreviewCompositor: NSObject, AVVideoCompositing {
    let sourcePixelBufferAttributes: [String: any Sendable]? = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? PreviewInstruction,
              let source = request.sourceFrame(byTrackID: instruction.sourceTrackID),
              let output = request.renderContext.newPixelBuffer()
        else {
            request.finish(with: ExportError.reader(nil))
            return
        }
        let image = instruction.renderer.render(source: CIImage(cvPixelBuffer: source), at: request.compositionTime.seconds)
        let size = CGSize(width: CVPixelBufferGetWidth(output), height: CVPixelBufferGetHeight(output))
        context.render(image, to: output, bounds: CGRect(origin: .zero, size: size), colorSpace: colorSpace)
        request.finish(withComposedVideoFrame: output)
    }
}

/// The raw screen video and its audio on one timeline, ready for a player item.
struct PreviewAsset {
    let composition: AVMutableComposition
    let videoTrackID: CMPersistentTrackID
    let audioMix: AVAudioMix?
    let duration: CMTime

    static func make(for folder: RecordingFolder, duration seconds: Double) async throws -> PreviewAsset {
        let composition = AVMutableComposition()
        let source = AVURLAsset(url: folder.video)
        guard let videoSource = try await source.loadTracks(withMediaType: .video).first,
              let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw ExportError.noVideoTrack }
        let duration = CMTime.seconds(seconds)
        let available = try await videoSource.load(.timeRange)
        try video.insertTimeRange(CMTimeRange(start: available.start, duration: CMTimeMinimum(duration, available.duration)),
                                  of: videoSource, at: .zero)
        let audio = try await AudioMixSource.addAudio(from: folder, duration: seconds, to: composition)
        return PreviewAsset(composition: composition, videoTrackID: video.trackID, audioMix: audio?.mix, duration: duration)
    }

    func videoComposition(renderer: FrameRenderer, fps: Double) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = PreviewCompositor.self
        videoComposition.renderSize = renderer.canvas
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        videoComposition.instructions = [
            PreviewInstruction(timeRange: CMTimeRange(start: .zero, duration: duration), renderer: renderer, sourceTrackID: videoTrackID),
        ]
        return videoComposition
    }
}

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
