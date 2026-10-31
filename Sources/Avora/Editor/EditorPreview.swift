import AVFoundation
import AppKit
import CoreImage
import SwiftUI
import ZoomEngine

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
    let cameraTrackID: CMPersistentTrackID?
    /// Turns the video's clock back into the recording's, which the renderer works in.
    let clips: ClipList

    init(timeRange: CMTimeRange, renderer: FrameRenderer, sourceTrackID: CMPersistentTrackID, cameraTrackID: CMPersistentTrackID?, clips: ClipList) {
        self.timeRange = timeRange
        self.renderer = renderer
        self.sourceTrackID = sourceTrackID
        self.cameraTrackID = cameraTrackID
        self.clips = clips
        requiredSourceTrackIDs = ([sourceTrackID] + (cameraTrackID.map { [$0] } ?? [])).map { NSNumber(value: $0) }
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
        let time = instruction.clips.sourceTime(atOutput: request.compositionTime.seconds)
        let camera = instruction.cameraTrackID.flatMap { request.sourceFrame(byTrackID: $0) }.map { CIImage(cvPixelBuffer: $0) }
        let image = instruction.renderer.render(source: CIImage(cvPixelBuffer: source), camera: camera, at: time)
        let size = CGSize(width: CVPixelBufferGetWidth(output), height: CVPixelBufferGetHeight(output))
        context.render(image, to: output, bounds: CGRect(origin: .zero, size: size), colorSpace: colorSpace)
        request.finish(withComposedVideoFrame: output)
    }
}

/// The recording on the video's timeline, ready for a player item.
struct PreviewAsset {
    let composition: AVMutableComposition
    let videoTrackID: CMPersistentTrackID
    let cameraTrackID: CMPersistentTrackID?
    let audioMix: AVAudioMix?
    let duration: CMTime
    let clips: ClipList

    static func make(for folder: RecordingFolder, duration seconds: Double, clips: ClipList, voice: VoicePreset) async throws -> PreviewAsset {
        let timeline = try await TimelineComposition.make(for: folder, sourceDuration: seconds, clips: clips, video: true, voice: voice)
        guard let videoTrackID = timeline.videoTrackID else { throw ExportError.noVideoTrack }
        return PreviewAsset(composition: timeline.composition, videoTrackID: videoTrackID, cameraTrackID: timeline.cameraTrackID, audioMix: timeline.audioMix,
                            duration: .seconds(timeline.duration), clips: clips)
    }

    func videoComposition(renderer: FrameRenderer, fps: Double) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = PreviewCompositor.self
        videoComposition.renderSize = renderer.canvas
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        videoComposition.instructions = [
            PreviewInstruction(timeRange: CMTimeRange(start: .zero, duration: duration), renderer: renderer, sourceTrackID: videoTrackID, cameraTrackID: cameraTrackID, clips: clips),
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
