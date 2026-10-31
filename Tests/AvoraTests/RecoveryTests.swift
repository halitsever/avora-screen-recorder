import AVFoundation
import Foundation
import Testing
import ZoomEngine
@testable import Avora

private func makeRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(path: "avora-recover-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

struct RecoveryTests {
    @Test func unfinishedRecordingsAreFound() throws {
        let root = try makeRoot()
        let finished = RecordingFolder(url: root.appending(path: "finished"))
        let crashed = RecordingFolder(url: root.appending(path: "crashed"))
        let empty = RecordingFolder(url: root.appending(path: "empty"))
        for folder in [finished, crashed, empty] { try FileManager.default.createDirectory(at: folder.cursors, withIntermediateDirectories: true) }
        try Data().write(to: finished.video)
        try Data().write(to: finished.log)
        try Data().write(to: crashed.video)
        try Data().write(to: crashed.partialLog)
        #expect(RawRecordings.unfinished(in: root).map(\.url.lastPathComponent) == ["crashed"])
    }

    @Test func recoveringKeepsTheInputWrittenSoFar() throws {
        let root = try makeRoot()
        let folder = RecordingFolder(url: root.appending(path: "crashed"))
        try FileManager.default.createDirectory(at: folder.cursors, withIntermediateDirectories: true)
        try Data().write(to: folder.video)
        let log = InputLog(sourceSize: CGSize(width: 100, height: 100), pointPixelScale: 1, duration: 4)
        try JSONEncoder().encode(log).write(to: folder.partialLog)
        try RawRecordings.markRecovered(folder)
        #expect(FileManager.default.fileExists(atPath: folder.log.path))
        #expect(!FileManager.default.fileExists(atPath: folder.partialLog.path))
        #expect(RawRecordings.unfinished(in: root).isEmpty)
    }

    /// A writer that is never finished, as when the app is killed, still leaves a readable movie.
    @Test func fragmentedMovieSurvivesAnUnfinishedWriter() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "avora-fragment-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        writer.movieFragmentInterval = CMTime(seconds: 0.5, preferredTimescale: 600)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64,
        ])
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64,
        ])
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            adaptor.append(buffer!, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        // Give the writer time to flush fragments, then walk away without finishing.
        try await Task.sleep(for: .milliseconds(800))
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        #expect(duration >= 1)
        writer.cancelWriting()
    }
}
